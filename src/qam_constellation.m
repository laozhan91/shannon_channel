function c = qam_constellation(M)
%QAM_CONSTELLATION 构造 Gray 映射方形 QAM 星座（平均符号功率归一化为 1）
%
%   c = qam_constellation(M)
%
%   M = 4 / 16 / 64 ...
%
% 返回结构体：
%   c.M        : 调制阶数
%   c.bitsPerSym : log2(M)（每符号比特数）
%   c.bitsPerDim : log2(M)/2（每维比特数）
%   c.symbols  : 1 x M 复星座点，按“符号索引 m = gI*L + gQ”排列
%   c.bits     : M x log2(M) 每个符号对应的比特（MSB 在前，前一半为 I 路）
%   c.pam      : 1 x L 每维 PAM 电平（实部幅度）
%   c.gOfN     : L x 1 自然序电平序号 n -> Gray 标签 g 的映射
%   c.d        : PAM 最小间距（用于硬判决快速反解）
%
% 备注：Gray 映射保证相邻星座点仅相差 1 bit。

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'double', 'ValueType', 'any');
end
if isKey(cache, M)
    c = cache(M);
    return;
end

bitsPerSym = round(log2(M));
if 2^bitsPerSym ~= M || mod(bitsPerSym, 2) ~= 0
    error('qam_constellation: M 必须是 4 的幂（方形 QAM）。');
end
b = bitsPerSym / 2;
L = 2^b;

% Gray -> 二进制自然序（gray2bin）；相邻电平只差 1 bit
n = (0:L-1).';
for sh = [1 2 4]
    n = bitxor(n, bitshift(n, -sh));
end

% 自然序电平序号 -> Gray 标签
gOfN = zeros(L, 1);
for k = 1:L
    g = k - 1;
    gOfN(n(k) + 1) = g;      % n(k) 是 gray 标签 (k-1) 对应的自然序序号
end

pamNominal = 2*(0:L-1) - (L-1);          % 例如 16-QAM: -3,-1,+1,+3
d = 1/sqrt(2 * mean(pamNominal.^2));     % 使 2 维平均功率 = 1
pam = pamNominal * d;

% 按 Gray 标签排列每维电平
pamByLabel = zeros(1, L);
for g = 0:L-1
    pamByLabel(g+1) = pam(n(g+1) + 1);
end
c.d = d;
c.pam = pamByLabel;

% 星座点与比特映射
M = 2^(2*b);
symbols = zeros(1, M);
bits = zeros(M, bitsPerSym);
for gI = 0:L-1
    for gQ = 0:L-1
        m = gI*L + gQ;                       % 0-based 符号索引
        symbols(m+1) = pamByLabel(gI+1) + 1i*pamByLabel(gQ+1);
        bits(m+1, :) = [dec2bin(gI, b) - '0', dec2bin(gQ, b) - '0'];
    end
end

c.M = M;
c.bitsPerSym = bitsPerSym;
c.bitsPerDim = b;
c.symbols = symbols;
c.bits = bits;
c.gOfN = gOfN;
cache(M) = c;
end
