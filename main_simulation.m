function main_simulation(profile, forceRecalibrate)
%MAIN_SIMULATION 主入口：一键运行全部仿真、生成 3 张图与全部数据
%
%   main_simulation                        % 默认 'balanced' 参数（约 10~20 分钟）
%   main_simulation('fast')                % 快速模式（约 3~5 分钟，精度略降）
%   main_simulation('balanced', true)      % 忽略缓存，强制重新标定切换表
%   main_simulation('accurate')            % 高精度模式（耗时最长）
%
% 流程：
%   1) 香农界：C/B = log2(1+SNR)，并换算 B = 3.2 kHz / 4 kHz 的绝对容量
%   2) 无编码 QPSK/16-QAM/64-QAM 的 BER 蒙特卡洛仿真 -> 有效频谱效率
%   3) 标定 SNR -> (调制,码率) 切换表（缓存于 results/data/switch_table.mat）
%   4) 自适应 Turbo-QAM 逐 SNR 点仿真（净频谱效率 + 吞吐量 + 实测 BER）
%   5) 保存数据（.mat/.csv）与 3 张图（.png/.fig）

if nargin < 1 || isempty(profile)
    profile = 'balanced';
end
if nargin < 2 || isempty(forceRecalibrate)
    forceRecalibrate = false;
end

tAll = tic;
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root, 'src'));

cfg = config_params(profile);
rng(cfg.seed);

fprintf('====================================================================\n');
fprintf(' 3.2-4 kHz 窄带链路：自适应 Turbo-QAM (AMC) 与香农界对比仿真\n');
fprintf('====================================================================\n');
fprintf(' 参数档位      : %s\n', cfg.profile);
fprintf(' SNR 范围      : %g ~ %g dB (Es/N0)，步长 %g dB\n', cfg.snrRange(1), cfg.snrRange(end), median(diff(cfg.snrRange)));
fprintf(' 目标 BER      : %.0e\n', cfg.targetBER);
fprintf(' 带宽          : %s Hz\n', mat2str(cfg.bandwidths));
fprintf(' Turbo 码      : 块长 %d，迭代 %d 次，算法 %s，码率 %s\n', ...
        cfg.turbo.blockLen, cfg.turbo.nIter, cfg.turbo.algorithm, mat2str(cfg.turbo.nominalRates, 4));
fprintf(' Turbo 引擎    : %s（auto = 优先使用 Communications Toolbox，无工具箱时自动降级）\n', cfg.turbo.engine);
fprintf(' 切换档位数    : %d\n', size(cfg.comboTable, 1));
fprintf('====================================================================\n');

res = struct();
res.cfg   = cfg;
res.snrDb = cfg.snrRange(:).';

%% ---------------- 1. 香农界 ----------------
fprintf('\n[1/5] 计算香农界 ...\n');
res.shannon = shannon_bound(cfg.snrRange, cfg.bandwidths);
fprintf('      C/B(0 dB)=%.3f, C/B(10 dB)=%.3f, C/B(20 dB)=%.3f bit/s/Hz\n', ...
        res.shannon.eta(res.shannon.snrDb == 0), res.shannon.eta(res.shannon.snrDb == 10), ...
        res.shannon.eta(res.shannon.snrDb == 20));

%% ---------------- 2. 无编码固定调制 ----------------
fprintf('\n[2/5] 无编码 QPSK / 16-QAM / 64-QAM BER 仿真 ...\n');
res.uncoded = [];
for M = cfg.qamOrders
    fprintf('      %s ...\n', mod_name(M));
    u = simulate_uncoded_qam(cfg, M, cfg.snrRange, struct('tag', 'uncoded'));
    if isempty(res.uncoded)
        res.uncoded = u;
    else
        res.uncoded(end+1) = u;   %#ok<AGROW>
    end
    valid = ~isnan(u.eta);
    if any(valid)
        fprintf('        达标(BER<=%.0e)起始 SNR = %g dB\n', cfg.targetBER, min(u.snrDb(valid)));
    else
        fprintf('        在仿真 SNR 范围内未达标\n');
    end
end

%% ---------------- 3. 切换表标定 ----------------
fprintf('\n[3/5] 标定 SNR -> (调制, 码率) 切换表 ...\n');
calOpts = struct('force', forceRecalibrate, 'verbose', true);
res.tbl = calibrate_switch_table(cfg, calOpts);

%% ---------------- 4. 自适应仿真 ----------------
fprintf('\n[4/5] 自适应 Turbo-QAM 仿真 ...\n');
res.adaptive = adaptive_amc_sim(cfg, res.tbl, cfg.snrRange, ...
                                struct('minBits', cfg.sim.adaptiveMinBits, ...
                                       'maxBits', cfg.sim.adaptiveMaxBits, ...
                                       'maxErrors', cfg.sim.adaptiveMaxErrors, ...
                                       'tag', 'adaptive', 'verbose', true));
res.adaptive.bandwidths = cfg.bandwidths(:).';

%% ---------------- 5. 汇总、保存、绘图 ----------------
fprintf('\n[5/5] 保存数据与绘图 ...\n');
res.summary = build_summary(cfg, res);
save_results(cfg, res);
res.figs = plot_results(cfg, res);

print_summary(cfg, res);

fprintf('\n 总耗时 %.1f 分钟。结果目录：\n', toc(tAll)/60);
fprintf('   figures: %s\n', cfg.paths.figures);
fprintf('   data   : %s\n', cfg.paths.data);
end

% ======================================================================
function s = build_summary(cfg, res)
gaps = [res.tbl.threshold] - shannon_snr_for_eta([res.tbl.eta]);
s.gapPerTier_dB = gaps;
s.gapMean_dB    = mean(gaps(~isnan(gaps)));
s.gapMax_dB     = max(gaps);
s.gapMin_dB     = min(gaps);
s.engineUsed    = unique(res.adaptive.engine(~cellfun(@isempty, res.adaptive.engine)));
end

% ======================================================================
function print_summary(cfg, res)
fprintf('\n==================== 结果摘要 ====================\n');

fprintf('\n切换表（目标 BER <= %.0e）：\n', cfg.targetBER);
fprintf(' 档  调制    码率    eta(净)   门限(dB)  香农限(dB)  差距(dB)\n');
fprintf(' -----------------------------------------------------------\n');
for i = 1:numel(res.tbl)
    t = res.tbl(i);
    sh = shannon_snr_for_eta(t.eta);
    gap = t.threshold - sh;
    flag = '';
    if ~t.valid, flag = '  [未达标]'; end
    fprintf('  %d  %-7s %.3f   %.3f    %8.2f   %8.2f   %6.2f%s\n', ...
            i, mod_name(t.M), t.R, t.eta, t.threshold, sh, gap, flag);
end

g = res.summary.gapPerTier_dB;
fprintf(' -----------------------------------------------------------\n');
fprintf(' 与香农界差距：平均 %.2f dB（最小 %.2f dB，最大 %.2f dB）\n', ...
        mean(g(~isnan(g))), min(g), max(g));

% 典型 SNR 处的方案对比
snrShow = [6 12 18 24];
snrShow = snrShow(snrShow >= min(res.snrDb) & snrShow <= max(res.snrDb));
fprintf('\n各方案净频谱效率 (bit/s/Hz) 对比：\n');
fprintf('  SNR(dB)   香农界  ');
for k = 1:numel(res.uncoded)
    fprintf('%8s ', mod_name(res.uncoded(k).M));
end
fprintf('   自适应\n');
for s = snrShow
    idx = find(abs(res.snrDb - s) < 1e-9, 1);
    fprintf('  %6.1f    %6.2f   ', s, res.shannon.eta(idx));
    for k = 1:numel(res.uncoded)
        e = res.uncoded(k).eta(idx);
        if isnan(e)
            fprintf('%8s ', '--');
        else
            fprintf('%8.2f ', e);
        end
    end
    fprintf('  %6.2f\n', res.adaptive.eta(idx));
end

% 吞吐量
fprintf('\n自适应方案绝对吞吐量 (kbps)：\n');
fprintf('  SNR(dB)');
for k = 1:numel(res.adaptive.bandwidths)
    fprintf('   B=%.1fkHz', res.adaptive.bandwidths(k)/1e3);
end
fprintf('\n');
for s = snrShow
    idx = find(abs(res.snrDb - s) < 1e-9, 1);
    fprintf('  %6.1f ', s);
    for k = 1:numel(res.adaptive.bandwidths)
        fprintf('   %7.1f ', res.adaptive.throughputKbps(k, idx));
    end
    fprintf('\n');
end

% 一致性检查
bad = find(~res.adaptive.berValid & ~res.adaptive.outage);
if isempty(bad)
    fprintf('\n 自适应方案所有 SNR 点实测 BER 均满足 <= %.0e。\n', cfg.targetBER);
else
    fprintf('\n [警告] 有 %d 个点的实测 BER 超过门限：SNR = %s dB\n', ...
            numel(bad), mat2str(res.snrDb(bad)));
end
fprintf('==================================================\n');
end

% ======================================================================
function s = mod_name(M)
switch M
    case 4,  s = 'QPSK';
    case 16, s = '16-QAM';
    case 64, s = '64-QAM';
    otherwise, s = sprintf('%d-QAM', M);
end
end
