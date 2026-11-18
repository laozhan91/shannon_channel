function nFull = turbo_toolbox_full_len(N, cfg)
%TURBO_TOOLBOX_FULL_LEN Toolbox Turbo 编码器（未打孔母码）的输出长度
%
%   nFull = turbo_toolbox_full_len(N, cfg)
%
% comm.TurboEncoder 的母码为 1/3，输出按 [s(1) p1(1) p2(1) s(2) ...] 排列，
% 末尾附加归零尾比特，因此 nFull = 3*(N + 尾比特数)。

persistent cachedN cachedLen
if isempty(cachedN) || cachedN ~= N
    enc = turbo_toolbox_objects('encoder', N, cfg);
    cachedLen = numel(enc(zeros(N, 1)));
    cachedN = N;
end
nFull = cachedLen;
end
