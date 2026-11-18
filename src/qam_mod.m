function x = qam_mod(bits, M, c)
%QAM_MOD Gray 映射方形 QAM 调制
%
%   x = qam_mod(bits, M)       % bits: 1 x (K*log2(M)) 行向量，按“符号优先”排列
%   x = qam_mod(bits, M, c)    % 复用已构造的星座结构体 c = qam_constellation(M)
%
%   返回 K x 1 复基带符号（平均功率 1）

if nargin < 3 || isempty(c)
    c = qam_constellation(M);
end
bTot = c.bitsPerSym;
if numel(bits) ~= round(numel(bits)/bTot)*bTot
    error('qam_mod: 比特数必须是 log2(M) 的整数倍。');
end
K = numel(bits) / bTot;
B = reshape(bits, bTot, K).';              % K x bTot，每行一个符号的比特
w = 2.^(bTot-1:-1:0);                      % 比特权值（MSB 在前）
m = B * w(:);                              % 0-based 符号索引
x = c.symbols(m + 1).';
end
