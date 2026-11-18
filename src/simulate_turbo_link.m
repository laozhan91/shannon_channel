function res = simulate_turbo_link(cfg, M, R, snrDb, opts)
%SIMULATE_TURBO_LINK Turbo 编码 QAM 链路的单 SNR 点蒙特卡洛仿真
%
%   res = simulate_turbo_link(cfg, M, R, snrDb)
%   res = simulate_turbo_link(cfg, M, R, snrDb, opts)
%
%   opts.minBits / maxBits / maxErrors / tag
%
% 链路：随机比特 -> Turbo 编码 -> 符号补齐 -> Gray QAM -> AWGN
%       -> 软解调 LLR -> Turbo 迭代译码 -> 统计 BER
%
% 返回：
%   res.ber          : 实测误比特率
%   res.etaNominal   : R*log2(M)（净频谱效率，按名义码率，符合题目定义）
%   res.etaActual    : 实际码率（含归零尾比特与打孔）×log2(M)
%   res.rateActual   : 实际码率
%   res.engine       : 本次使用的 Turbo 实现（'toolbox' / 'native'）

if nargin < 5 || isempty(opts)
    opts = struct();
end
minBits   = opt_get(opts, 'minBits',   cfg.sim.adaptiveMinBits);
maxBits   = opt_get(opts, 'maxBits',   cfg.sim.adaptiveMaxBits);
maxErrors = opt_get(opts, 'maxErrors', cfg.sim.adaptiveMaxErrors);
tag       = opt_get(opts, 'tag', 'turbo');

N        = cfg.turbo.blockLen;
bTot     = log2(M);
noiseVar = 10^(-snrDb/10);
c        = qam_constellation(M);
local_rng(cfg, M, R, snrDb, tag);

nErr = 0; nBits = 0; nBlocks = 0; nCodedTotal = 0; engine = '';

while true
    txBits = randi([0 1], N, 1);

    [coded, info] = turbo_encode(txBits, R, cfg);
    engine = info.engine;
    nc = numel(coded);

    % 符号对齐：补零（收端作为已知比特处理，不影响信息比特统计）
    nPad = mod(-nc, bTot);
    codedPad = [coded, zeros(1, nPad)];

    K = numel(codedPad) / bTot;
    x = qam_mod(codedPad, M, c);
    y = x + sqrt(noiseVar/2) * (randn(K,1) + 1i*randn(K,1));

    llr = qam_demod_llr(y, M, noiseVar, c);
    llr = llr(1:nc);

    bitsHat = turbo_decode(llr, N, R, cfg);

    nErr        = nErr + sum(bitsHat(:) ~= txBits);
    nBits       = nBits + N;
    nBlocks     = nBlocks + 1;
    nCodedTotal = nCodedTotal + nc;

    if nErr >= maxErrors, break; end
    if nBits >= maxBits, break; end
    if nBits >= minBits && (nErr == 0 || nErr >= 20), break; end
end

res.M          = M;
res.R          = R;
res.snrDb      = snrDb;
res.ber        = nErr / nBits;
res.berUB      = (nErr + 1) / nBits;     % 保守上界（+1 伪计数）
res.errors     = nErr;
res.bits       = nBits;
res.blocks     = nBlocks;
res.rateActual = N / (nCodedTotal / nBlocks);
res.etaNominal = R * log2(M);
res.etaActual  = res.rateActual * log2(M);
res.engine     = engine;
res.nIter      = cfg.turbo.nIter;
end
