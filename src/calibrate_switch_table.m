function [tbl, calInfo] = calibrate_switch_table(cfg, opts)
%CALIBRATE_SWITCH_TABLE 标定 SNR -> (调制, 码率) 切换表
%
%   [tbl, calInfo] = calibrate_switch_table(cfg)
%   [tbl, calInfo] = calibrate_switch_table(cfg, opts)
%
%   opts.force   : true 时忽略缓存，强制重新标定（默认 false）
%   opts.verbose : 是否打印进度（默认 true）
%
% 标定思路：
%   对每种“调制+码率”组合，从该组合的香农限附近按 0.5 dB 步进提高 SNR，
%   蒙特卡洛测 BER，直到出现满足 BER <= cfg.targetBER 的点，再二分细化 0.25 dB，
%   取第一个实测达标点作为门限（误差 <= 0.25 dB），最后加 cfg.calib.margin_dB 余量。
%   最后做单调化：效率越高的档位，门限不得低于低效率档。
%
% 返回 tbl 结构体数组（字段 index/M/R/eta/threshold/valid/...），
% 并缓存到 results/data/switch_table.mat（含参数指纹，参数变化会自动重标定）。

if nargin < 2 || isempty(opts)
    opts = struct();
end
force   = opt_get(opts, 'force', false);
verbose = opt_get(opts, 'verbose', true);

fp = params_fingerprint(cfg);
if cfg.calib.reuseCache && ~force && exist(cfg.paths.switchTable, 'file') == 2
    S = load(cfg.paths.switchTable);
    if isfield(S, 'fingerprint') && strcmp(S.fingerprint, fp) && isfield(S, 'tbl')
        tbl = S.tbl;
        calInfo = S.calInfo;
        calInfo.fromCache = true;
        if verbose
            fprintf('  [cache] 读取已标定的切换表：%s\n', cfg.paths.switchTable);
        end
        return;
    end
end

comboOpts = struct('minBits', cfg.calib.minBits, ...
                   'maxBits', cfg.calib.maxBits, ...
                   'maxErrors', cfg.calib.targetErrors, ...
                   'tag', 'calib');

nC  = size(cfg.comboTable, 1);
tbl = repmat(struct('index', 0, 'M', 0, 'R', 0, 'eta', 0, 'threshold', NaN, ...
                    'valid', false, 'snrCurve', [], 'berCurve', [], ...
                    'bitsCurve', [], 'errCurve', [], 'engine', ''), 1, nC);
tStart = tic;

for i = 1:nC
    M   = cfg.comboTable(i, 1);
    R   = cfg.comboTable(i, 2);
    eta = R * log2(M);
    snrShannon = shannon_snr_for_eta(eta);

    if verbose
        fprintf('\n  [%d/%d] M=%-2d  R=%.4f  eta=%.3f bit/s/Hz  香农限=%.2f dB\n', ...
                i, nC, M, R, eta, snrShannon);
    end

    snrGrid = (snrShannon + cfg.calib.startOffset_dB) : cfg.calib.coarseStep_dB : ...
              (snrShannon + cfg.calib.searchEnd_dB);

    snrVals = []; berVals = []; bitVals = []; errVals = []; engUsed = '';
    passIdx = [];
    for s = snrGrid
        t1 = tic;
        r = simulate_turbo_link(cfg, M, R, s, comboOpts);
        engUsed = r.engine;
        snrVals(end+1) = s;              %#ok<AGROW>
        berVals(end+1) = r.ber;          %#ok<AGROW>
        bitVals(end+1) = r.bits;         %#ok<AGROW>
        errVals(end+1) = r.errors;       %#ok<AGROW>
        if verbose
            fprintf('        SNR=%6.2f dB  BER=%.2e  (%3d 错 / %.2e bit, %s, %.1f s)\n', ...
                    s, r.ber, r.errors, r.bits, r.engine, toc(t1));
        end
        if r.ber <= cfg.targetBER
            passIdx = numel(snrVals);
            break;
        end
    end

    % 细化一次（0.25 dB），使夹逼区间更紧
    if ~isempty(passIdx) && passIdx > 1
        lo = snrVals(passIdx-1);
        hi = snrVals(passIdx);
        mid = lo + cfg.calib.fineStep_dB;
        if mid >= hi
            mid = (lo + hi)/2;
        end
        r = simulate_turbo_link(cfg, M, R, mid, comboOpts);
        snrVals(end+1) = mid;        %#ok<AGROW>
        berVals(end+1) = r.ber;      %#ok<AGROW>
        bitVals(end+1) = r.bits;     %#ok<AGROW>
        errVals(end+1) = r.errors;   %#ok<AGROW>
        if verbose
            fprintf('        [细化] SNR=%6.2f dB  BER=%.2e  (%3d 错 / %.2e bit)\n', ...
                    mid, r.ber, r.errors, r.bits);
        end
        if r.ber <= cfg.targetBER
            hi = mid;
        else
            lo = mid;
        end
    elseif ~isempty(passIdx)
        lo = snrVals(1) - cfg.calib.coarseStep_dB;
        hi = snrVals(1);
    else
        lo = NaN; hi = NaN;
    end

    % ---- 门限估计：第一个实测达标点（已用 0.25 dB 细化，误差 <= 0.25 dB）----
    if isempty(passIdx)
        % 搜索窗内未达标：用可靠点的 log-BER 线性拟合外推，并标记为无效档
        rel = find(errVals >= 10 & berVals > 0 & berVals <= 0.2);
        thr = NaN;
        if numel(rel) >= 2
            pfit = polyfit(snrVals(rel), log10(berVals(rel)), 1);
            if pfit(1) < 0
                thr = (log10(cfg.targetBER) - pfit(2)) / pfit(1);
            end
        end
        valid = isfinite(thr);
        if verbose
            fprintf('        ! 搜索窗内未达标，拟合外推门限 %.2f dB（标记为无效档）\n', thr);
        end
    else
        thr   = hi;
        valid = true;
    end

    if verbose
        fprintf('        -> 门限 %.2f dB（达标区间 [%.2f, %.2f]），+%.2f dB 余量 = %.2f dB\n', ...
                thr, lo, hi, cfg.calib.margin_dB, thr + cfg.calib.margin_dB);
    end

    tbl(i).index     = i;
    tbl(i).M         = M;
    tbl(i).R         = R;
    tbl(i).eta       = eta;
    tbl(i).threshold = thr + cfg.calib.margin_dB;
    tbl(i).valid     = valid;
    tbl(i).snrCurve  = snrVals;
    tbl(i).berCurve  = berVals;
    tbl(i).bitsCurve = bitVals;
    tbl(i).errCurve  = errVals;
    tbl(i).engine    = engUsed;
end

% ---------------- 单调化：效率越高，门限不得低于低效率档 ----------------
[~, ord] = sort([tbl.eta]);
runMax = -Inf;
for j = ord
    if isnan(tbl(j).threshold)
        continue;
    end
    tbl(j).threshold = max(tbl(j).threshold, runMax);
    runMax = tbl(j).threshold;
end

calInfo.fingerprint = fp;
calInfo.createdAt   = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
calInfo.elapsedSec  = toc(tStart);
calInfo.fromCache   = false;
calInfo.targetBER   = cfg.targetBER;

if ~exist(cfg.paths.data, 'dir')
    mkdir(cfg.paths.data);
end
fingerprint = fp;    %#ok<NASGU>  供外部脚本读取
save(cfg.paths.switchTable, 'tbl', 'calInfo', 'fingerprint');
if verbose
    fprintf('\n  标定完成，用时 %.1f s，结果已保存：%s\n', calInfo.elapsedSec, cfg.paths.switchTable);
end
end
