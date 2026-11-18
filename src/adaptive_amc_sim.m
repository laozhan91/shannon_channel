function res = adaptive_amc_sim(cfg, tbl, snrVec, opts)
%ADAPTIVE_AMC_SIM 自适应 Turbo-QAM（AMC）逐 SNR 点仿真
%
%   res = adaptive_amc_sim(cfg, tbl, snrVec)
%
%   对每个 SNR：
%     1) 查切换表，选择“门限 <= SNR 的最高净频谱效率”档位；
%     2) 仿真该档位的实际 BER（蒙特卡洛），验证门限是否可靠；
%     3) 记录净频谱效率 eta = R*log2(M) 与绝对吞吐量 eta*B。
%   SNR 低于最低门限时判定为中断（outage），不发送数据（eta = 0）。

if nargin < 4 || isempty(opts)
    opts = struct();
end
verbose = opt_get(opts, 'verbose', true);

nS = numel(snrVec);
res.snrDb    = snrVec(:).';
res.tier     = zeros(1, nS);
res.M        = nan(1, nS);
res.R        = nan(1, nS);
res.eta      = zeros(1, nS);
res.ber      = nan(1, nS);
res.berUB    = nan(1, nS);
res.errors   = zeros(1, nS);
res.bits     = zeros(1, nS);
res.outage   = false(1, nS);
res.engine   = cell(1, nS);
res.berValid = true(1, nS);

if verbose
    fprintf('\n  自适应 Turbo-QAM 仿真（%d 个 SNR 点）\n', nS);
    fprintf('    SNR   档位  调制     码率    eta     BER        状态\n');
end

for i = 1:nS
    [tier, sel] = select_combo(tbl, res.snrDb(i));
    res.tier(i) = tier;

    if tier == 0
        res.outage(i) = true;          % 链路中断，不发送
        res.eta(i) = 0;
        if verbose
            fprintf('   %5.1f   --   中断（低于最低门限）        0\n', res.snrDb(i));
        end
        continue;
    end

    r = simulate_turbo_link(cfg, sel.M, sel.R, res.snrDb(i), opts);

    res.M(i)        = sel.M;
    res.R(i)        = sel.R;
    res.eta(i)      = sel.eta;
    res.ber(i)      = r.ber;
    res.berUB(i)    = r.berUB;
    res.errors(i)   = r.errors;
    res.bits(i)     = r.bits;
    res.engine{i}   = r.engine;
    res.berValid(i) = (r.ber <= cfg.targetBER);

    if verbose
        fprintf('   %5.1f   %2d   %-6s  %.3f  %.3f  %.2e  %s(%s)\n', ...
                res.snrDb(i), tier, sprintf('%dQAM', sel.M), sel.R, sel.eta, ...
                r.ber, ternary(res.berValid(i), '达标', '未达标'), r.engine);
    end
end

% 绝对吞吐量：kbps = B[Hz] * eta[bit/s/Hz] / 1000
res.throughputKbps = cfg.bandwidths(:) * res.eta / 1e3;
res.bandwidths     = cfg.bandwidths(:).';
end

% ----------------------------------------------------------------------
function s = ternary(cond, a, b)
if cond
    s = a;
else
    s = b;
end
end
