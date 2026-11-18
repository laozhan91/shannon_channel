function [coded, info] = turbo_native_encode(bits, R, cfg)
%TURBO_NATIVE_ENCODE 本工程自带的 PCCC Turbo 编码器（支持打孔）
%
%   [coded, info] = turbo_native_encode(bits, R, cfg)
%
%   结构：8 状态 RSC（3GPP LTE 分量码）+ 伪随机交织 + 并行级联，母码 1/3，
%         通过打孔得到 1/3、1/2、2/3、3/4 码率。
%   归零：编码器 1 用 3 个尾比特强制回到零状态；编码器 2 使用同样的尾比特
%         （其终止状态由译码器按“未知”处理，对性能无实质影响）。
%   输出 coded 为 1 x nCoded 行向量（不含符号补齐比特）。

bits = bits(:);
N = numel(bits);
Ridx = code_rate_index(R, cfg);
perm = turbo_perm(N, cfg.turbo.interleaverSeed);
T = rsc_trellis(cfg.turbo.genPoly, cfg.turbo.constraintLen);

tailLen = cfg.turbo.tailLen;
L = N + tailLen;

% 编码器 1：数据 + 归零尾比特（递归码必须用反馈比特归零，不能直接补 0）
[par1, s1]    = rsc_encode(bits, T, 0);
tail          = rsc_terminate(s1, T);
[parT, sEnd1] = rsc_encode(tail, T, s1);
if sEnd1 ~= 0
    warning('turbo_native_encode: 编码器 1 未归零（末状态 %d）。', sEnd1);
end

% 编码器 2：交织后数据 + 同样的尾比特
[par2, sEnd2] = rsc_encode([bits(perm); tail], T, 0);

u = [bits; tail];

mother = zeros(3*L, 1);
mother(1:3:end) = u;
mother(2:3:end) = [par1; parT];
mother(3:3:end) = par2;

mask = puncture_mask(L, Ridx);
coded = mother(mask).';

info.perm       = perm;
info.mask       = mask;
info.nCoded     = numel(coded);
info.L          = L;
info.rateIndex  = Ridx;
info.rateActual = N / numel(coded);
info.tail       = tail;
info.sEnd2      = sEnd2;
end
