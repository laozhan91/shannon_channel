function snrDb = shannon_snr_for_eta(eta)
%SHANNON_SNR_FOR_ETA 给定频谱效率 eta，反解所需的最小 SNR (dB)：2^eta - 1
%
%   snrDb = shannon_snr_for_eta(eta)

snr = 2.^eta - 1;
snrDb = 10*log10(snr);
snrDb(eta <= 0) = -Inf;
end
