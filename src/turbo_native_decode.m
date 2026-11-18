function [bitsHat, info] = turbo_native_decode(llr, N, R, cfg)
%TURBO_NATIVE_DECODE 本工程自带的 Turbo 迭代译码器（Log-MAP，支持打孔反解）
%
%   [bitsHat, info] = turbo_native_decode(llr, N, R, cfg)
%
%   llr : 1 x nCoded 编码比特的 LLR（顺序与 turbo_native_encode 输出一致）
%   N   : 信息块长
%   R   : 名义码率
%
%   迭代 cfg.turbo.nIter 次，返回 N x 1 信息比特估计。

Ridx = code_rate_index(R, cfg);
perm = turbo_perm(N, cfg.turbo.interleaverSeed);
T    = rsc_trellis(cfg.turbo.genPoly, cfg.turbo.constraintLen);
tailLen = cfg.turbo.tailLen;
L = N + tailLen;

% 反打孔：被打孔的比特 LLR 置 0（擦除）
mask = puncture_mask(L, Ridx);
mother = zeros(3*L, 1);
mother(mask) = llr(:);

Lsys = mother(1:3:end);
Lp1  = mother(2:3:end);
Lp2  = mother(3:3:end);

% 编码器 2 工作在交织域
LsysV = zeros(L, 1);
LsysV(1:N) = Lsys(perm);
LsysV(N+1:end) = Lsys(N+1:end);      % 归零尾比特位置（系统位未被删除）

La1 = zeros(L, 1);                   % 编码器 1 的先验
for it = 1:cfg.turbo.nIter
    % 编码器 1 归零结束；编码器 2 终止状态未知（均匀初始化）
    [~, Le1] = logmap_decode_rsc(Lsys, Lp1, La1, T, cfg.turbo.algorithm, true);

    La2 = zeros(L, 1);
    La2(1:N) = Le1(perm);            % u 域 -> 交织域：v(j)=u(perm(j)) → La2(j)=Le1(perm(j))

    [Lpost2, Le2] = logmap_decode_rsc(LsysV, Lp2, La2, T, cfg.turbo.algorithm, false);

    La1 = zeros(L, 1);
    La1(perm) = Le2(1:N);            % 交织域 -> u 域
end

bitsHat = zeros(N, 1);
bitsHat(perm) = (Lpost2(1:N) < 0);    % LLR>0 -> 0, LLR<0 -> 1
info.iterations = cfg.turbo.nIter;
info.algorithm  = cfg.turbo.algorithm;
end
