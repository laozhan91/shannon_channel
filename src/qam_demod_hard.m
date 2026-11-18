function bits = qam_demod_hard(y, M, c)
%QAM_DEMOD_HARD 方形 QAM 硬判决解调（可分离判决，O(K) 复杂度）
%
%   bits = qam_demod_hard(y, M)
%
%   y    : K x 1 复基带接收符号
%   bits : 1 x (K*log2(M)) 判决比特，按“符号优先”排列（与 qam_mod 对应）

if nargin < 3 || isempty(c)
    c = qam_constellation(M);
end
b = c.bitsPerDim;
L = 2^b;
K = numel(y);
chunk = 2e5;                       % 分块以控制内存
bits = zeros(1, K*c.bitsPerSym);

for k0 = 1:chunk:K
    idx = k0:min(k0+chunk-1, K);
    yc = y(idx);
    % 每维独立取最近 PAM 电平：电平间隔 d，自然序序号 n = round((a/d + L-1)/2)
    nI = round((real(yc) / c.d + (L-1)) / 2);
    nQ = round((imag(yc) / c.d + (L-1)) / 2);
    nI = min(max(nI, 0), L-1);
    nQ = min(max(nQ, 0), L-1);
    gI = c.gOfN(nI + 1);
    gQ = c.gOfN(nQ + 1);
    m = gI*L + gQ;                     % 0-based 符号索引
    bm = c.bits(m + 1, :);             % 每行一个符号的比特
    bits((k0-1)*c.bitsPerSym + (1:numel(idx)*c.bitsPerSym)) = reshape(bm.', 1, []);
end
end
