function T = rsc_trellis(genPoly, K)
%RSC_TRELLIS 递归系统卷积码（RSC）的 8 状态网格表
%
%   T = rsc_trellis([13 15], 4)
%
% 状态 s = 4*a1 + 2*a2 + a3，a1/a2/a3 为最近 3 个反馈比特（a1 最新）。
% 与 MATLAB poly2trellis(4,[13 15],13) 的网格完全一致（见 test_turbo_awgn.m）：
%   反馈：fb = u ⊕ a2 ⊕ a3        -> 寄存器输入（下一状态的最高位）
%   校验：p  = u ⊕ a1 ⊕ a2
% 该结构即 3GPP LTE 的 8 状态 RSC 分量码。
%
% 返回（除 NS/PAR 外，还预计算 BCJR 需要的“分支对”索引，避免逐比特查表）：
%   T.NS     : 8 x 2  T.NS(s+1,u+1) = 下一状态（0..7）
%   T.PAR    : 8 x 2  T.PAR(s+1,u+1) = 校验比特
%   T.NSP    : 16 x 1 分支对 p=2s+u+1 对应的下一状态
%   T.SYSP   : 16 x 1 分支对 p 的系统比特符号 (1-2u)
%   T.PARS   : 16 x 1 分支对 p 的校验比特符号 (1-2p)
%   T.PREDA  : 8 x 1  到达状态 ns 的第 1 条入分支的分支对编号
%   T.PREDB  : 8 x 1  到达状态 ns 的第 2 条入分支的分支对编号
%   T.SRCA   : 8 x 1  第 1 条入分支的源状态
%   T.SRCB   : 8 x 1  第 2 条入分支的源状态

persistent cached Tcache
key = [genPoly K];
if ~isempty(cached) && isequal(cached, key)
    T = Tcache;
    return;
end

nStates = 2^(K-1);
NS  = zeros(nStates, 2);
PAR = zeros(nStates, 2);
for s = 0:nStates-1
    a1 = bitget(s, 3);
    a2 = bitget(s, 2);
    a3 = bitget(s, 1);
    for u = 0:1
        fb = mod(u + a2 + a3, 2);
        p  = mod(u + a1 + a2, 2);
        NS(s+1, u+1)  = 4*fb + 2*a1 + a2;
        PAR(s+1, u+1) = p;
    end
end

% ---- 分支对（p = 2s + u + 1）----
NSP  = zeros(16, 1);
SYSP = zeros(16, 1);
PARS = zeros(16, 1);
for s = 0:nStates-1
    for u = 0:1
        p = 2*s + u + 1;
        NSP(p)  = NS(s+1, u+1);
        SYSP(p) = 1 - 2*u;
        PARS(p) = 1 - 2*PAR(s+1, u+1);
    end
end

% ---- 每个下一状态的 2 条入分支 ----
inc = cell(nStates, 1);
for p = 1:16
    inc{NSP(p)+1}(end+1) = p;
end
PREDA = zeros(nStates, 1); PREDB = zeros(nStates, 1);
SRCA  = zeros(nStates, 1); SRCB  = zeros(nStates, 1);
for ns = 0:nStates-1
    PREDA(ns+1) = inc{ns+1}(1);
    PREDB(ns+1) = inc{ns+1}(2);
    SRCA(ns+1)  = floor((PREDA(ns+1)-1)/2);
    SRCB(ns+1)  = floor((PREDB(ns+1)-1)/2);
end

T.NS = NS;
T.PAR = PAR;
T.nStates = nStates;
T.genPoly = genPoly;
T.NSP = NSP;
T.SYSP = SYSP;
T.PARS = PARS;
T.PREDA = PREDA;
T.PREDB = PREDB;
T.SRCA = SRCA;
T.SRCB = SRCB;

cached = key;
Tcache = T;
end
