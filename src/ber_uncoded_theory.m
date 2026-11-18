function ber = ber_uncoded_theory(M, snrDb)
%BER_UNCODED_THEORY 无编码方形 QAM（Gray 映射）理论误比特率
%
%   ber = ber_uncoded_theory(M, snrDb)
%
% SNR 采用 Es/N0（符号功率 1，复噪声方差 N0 = 10^(-SNR_dB/10)）。
% 精确表达式：
%   BER = (4/b) * (1 - 1/sqrt(M)) * Q( sqrt(3*SNR/(M-1)) ),  b = log2(M)
%
% 对 M = 4：BER = Q(sqrt(SNR))。
% 等价写法（以 Eb/N0 表示，Eb = Es/log2(M)）：BER = Q(sqrt(2*Eb/N0)) * 修正项，
% 即用户常见的 qfunc(sqrt(2*SNR)) 形式只在 snrDb 被定义为 Eb/N0 时成立，
% 与本工程 SNR = Es/N0 的定义相差 3 dB（QPSK）。详见 README。
%
% M = 16/64 时该式是 Gray 映射下的高 SNR 近似（误差 < 0.1 dB）。

snr = 10.^(snrDb/10);
b = log2(M);
ber = (4/b) * (1 - 1/sqrt(M)) .* qfun(sqrt(3*snr/(M-1)));
ber(snrDb == -Inf) = 0.5;
end
