function llr = qam_demod_llr(y, M, noiseVar, c)
%QAM_DEMOD_LLR 方形 QAM 精确（log-sum-exp）软解调
%
%   llr = qam_demod_llr(y, M, noiseVar)
%
%   y        : K x 1 复基带接收符号
%   noiseVar : 复噪声方差 N0（符号功率为 1 时 N0 = 10^(-SNR_dB/10)）
%   llr      : 1 x (K*log2(M)) 比特对数似然比，按“符号优先”排列
%
% 约定：LLR(b) = ln[ P(b=0|y) / P(b=1|y) ]，正值判为比特 0。
% 该约定与 turbo_decode 的内部约定完全一致。

if nargin < 4 || isempty(c)
    c = qam_constellation(M);
end
y = y(:);
K = numel(y);
bTot = c.bitsPerSym;

llrSym = zeros(K, bTot);
chunk = 2e4;                     % 分块：单块 K x M 矩阵不超过约 1e6 元素
for k0 = 1:chunk:K
    idx = k0:min(k0+chunk-1, K);
    yc = y(idx);
    met = -abs(yc - c.symbols).^2 / noiseVar;     % K x M 度量（∝ log p(y|x)）
    met = met - max(met, [], 2);                  % 数值稳定
    for j = 1:bTot
        sel0 = (c.bits(:, j) == 0).';
        m0 = max(met(:, sel0), [], 2);
        m1 = max(met(:, ~sel0), [], 2);
        l0 = m0 + log(sum(exp(met(:, sel0) - m0), 2));
        l1 = m1 + log(sum(exp(met(:, ~sel0) - m1), 2));
        llrSym(idx, j) = l0 - l1;
    end
end
llr = reshape(llrSym.', 1, []);
end
