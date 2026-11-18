function sb = shannon_bound(snrDb, bandwidths)
%SHANNON_BOUND 香农界：频谱效率 C/B = log2(1+SNR) 与绝对容量 C = B*log2(1+SNR)
%
%   sb = shannon_bound(snrDb, bandwidths)
%
%   snrDb       : 1 x N SNR 向量 (dB, Es/N0)
%   bandwidths  : 1 x B 带宽向量 (Hz)
%
% 返回结构体：
%   sb.snrDb        : 1 x N
%   sb.snrLinear    : 1 x N
%   sb.eta          : 1 x N   频谱效率 (bit/s/Hz)
%   sb.capacityBps  : B x N   绝对容量 (bit/s)
%   sb.capacityKbps : B x N   绝对容量 (kbit/s)

snrDb = snrDb(:).';
sb.snrDb     = snrDb;
sb.snrLinear = 10.^(snrDb/10);
sb.eta       = log2(1 + sb.snrLinear);
sb.bandwidths = bandwidths(:).';
sb.capacityBps  = sb.bandwidths.' * sb.eta;      % B x N
sb.capacityKbps = sb.capacityBps / 1e3;
end
