function res = simulate_uncoded_qam(cfg, M, snrVec, opts)
%SIMULATE_UNCODED_QAM 固定调制、无编码的 BER 蒙特卡洛仿真
%
%   res = simulate_uncoded_qam(cfg, M, snrVec)
%   res = simulate_uncoded_qam(cfg, M, snrVec, opts)
%
%   opts.minBits   : 每 SNR 点最少比特数（默认 cfg.sim.uncodedMinBits）
%   opts.maxBits   : 每 SNR 点最多比特数（默认 cfg.sim.uncodedMaxBits）
%   opts.maxErrors : 误码数达到该值即停止（默认 cfg.sim.uncodedMaxErrors）
%
% 返回：
%   res.ber      : 实测 BER
%   res.eta      : 有效频谱效率 (bit/s/Hz)：仅当 BER<=cfg.targetBER 时为 log2(M)，否则 NaN
%   res.errors/bits/berTheory : 统计量

if nargin < 4 || isempty(opts)
    opts = struct();
end
minBits   = opt_get(opts, 'minBits',   cfg.sim.uncodedMinBits);
maxBits   = opt_get(opts, 'maxBits',   cfg.sim.uncodedMaxBits);
maxErrors = opt_get(opts, 'maxErrors', cfg.sim.uncodedMaxErrors);
tag       = opt_get(opts, 'tag', 'uncoded');

bTot = log2(M);
c = qam_constellation(M);
nS = numel(snrVec);

res.M     = M;
res.snrDb = snrVec(:).';
res.ber   = nan(1, nS);
res.errors = zeros(1, nS);
res.bits   = zeros(1, nS);
res.eta    = nan(1, nS);

for i = 1:nS
    snrDb    = res.snrDb(i);
    noiseVar = 10^(-snrDb/10);
    local_rng(cfg, M, 0, snrDb, tag);

    chunkBits = max(2e5, ceil(minBits/5));
    nErr = 0;
    nBits = 0;
    while true
        K  = ceil(chunkBits / bTot);
        nB = K * bTot;
        tx = randi([0 1], 1, nB);
        x  = qam_mod(tx, M, c);
        y  = x + sqrt(noiseVar/2) * (randn(K,1) + 1i*randn(K,1));
        rx = qam_demod_hard(y, M, c);

        nErr  = nErr + sum(rx ~= tx);
        nBits = nBits + nB;

        if nErr >= maxErrors, break; end
        if nBits >= maxBits,  break; end
        if nBits >= minBits
            if nErr == 0, break; end                    % 已观察不到错误（BER <= 1/nBits）
            if nErr >= 100, break; end                  % 统计量足够
            if nErr/nBits > 20*cfg.targetBER && nErr >= 30, break; end   % 明显不达标
        end
    end

    res.errors(i) = nErr;
    res.bits(i)   = nBits;
    res.ber(i)    = nErr / nBits;
    if res.ber(i) <= cfg.targetBER
        res.eta(i) = bTot;                              % 目标 BER 达成 -> 计入有效频谱效率
    end
end

res.berTheory = ber_uncoded_theory(M, res.snrDb);
end
