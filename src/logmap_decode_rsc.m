function [Lpost, Lext] = logmap_decode_rsc(Lsys, Lp, La, T, algorithm, terminated)
%LOGMAP_DECODE_RSC 单个 RSC 分量的 BCJR 译码（Log-MAP / Max-Log-MAP）
%
%   [Lpost, Lext] = logmap_decode_rsc(Lsys, Lp, La, T, algorithm, terminated)
%
%   Lsys : 1 x N 系统比特信道 LLR
%   Lp   : 1 x N 校验比特信道 LLR（打孔位置为 0，即“擦除”）
%   La   : 1 x N 先验 LLR
%   T    : rsc_trellis 生成的网格表
%   algorithm  : 'logmap'（精确，使用 max* 修正）或 'maxlog'（近似，更快）
%   terminated : true 表示网格归零结束（后向初始化为状态 0），
%                false 表示结束状态未知（后向初始化为均匀分布）
%
%   Lpost : 后验 LLR      Lext = Lpost - Lsys - La（外信息）
%
% LLR 约定：L = ln[P(b=0)/P(b=1)]，L>0 判为 0。
% 分支度量：gamma_p(k) = 0.5*( SYSP(p)*(Lsys+La) + PARS(p)*Lp )

if nargin < 6 || isempty(terminated)
    terminated = true;
end
useLLR = strcmpi(algorithm, 'logmap');
N = numel(Lsys);
Lsys = Lsys(:).';
Lp   = Lp(:).';
La   = La(:).';

NEG = -1e4;    % 不可达状态用有限大负数表示，避免 -Inf 产生 NaN

% ---- 16 x N 分支度量矩阵（隐式扩展）----
Lc = Lsys + La;                        % 1 x N
gP = 0.5 * (T.SYSP * Lc + T.PARS * Lp);   % 16 x N

% ---- 前向递归 ----
alpha = zeros(8, N+1);
alpha(:,1) = NEG;
alpha(1,1) = 0;

pa = T.PREDA;   pb = T.PREDB;
sa = T.SRCA + 1;   sb = T.SRCB + 1;
for k = 1:N
    ak = alpha(:,k);
    if useLLR
        alpha(:,k+1) = maxstar2(ak(sa) + gP(pa,k), ak(sb) + gP(pb,k));
    else
        alpha(:,k+1) = max(ak(sa) + gP(pa,k), ak(sb) + gP(pb,k));
    end
end

% ---- 后向递归 + 后验 ----
beta = zeros(8, N+1);
if terminated
    beta(:,N+1) = NEG;
    beta(1,N+1) = 0;               % 归零结尾 -> 终止状态 0
else
    beta(:,N+1) = 0;               % 终止状态未知 -> 均匀（对数域为 0）
end

idx0 = (1:2:15).';                       % u = 0 的分支对
idx1 = (2:2:16).';                       % u = 1 的分支对
src0 = floor((idx0-1)/2) + 1;            % 分支对 -> 源状态索引
src1 = floor((idx1-1)/2) + 1;
dst0 = T.NSP(idx0) + 1;
dst1 = T.NSP(idx1) + 1;

Lpost = zeros(1, N);
for k = N:-1:1
    bk = beta(:,k+1);
    b0 = gP(idx0,k) + bk(dst0);
    b1 = gP(idx1,k) + bk(dst1);
    t0 = alpha(src0,k) + b0;
    t1 = alpha(src1,k) + b1;
    if useLLR
        beta(:,k) = maxstar2(b0, b1);
        Lpost(k) = logsumexp8(t0) - logsumexp8(t1);
    else
        beta(:,k) = max(b0, b1);
        Lpost(k) = max(t0) - max(t1);
    end
end

Lext = Lpost(:) - Lsys(:) - La(:);
end

% ----------------------------------------------------------------------
function y = maxstar2(a, b)
%MAXSTAR2 max*(a,b) = max(a,b) + ln(1+exp(-|a-b|))
d = abs(a - b);
y = max(a, b) + log1p(exp(-d));
end

% ----------------------------------------------------------------------
function y = logsumexp8(v)
%LOGSUMEXP8 8 个元素的 log-sum-exp
m = max(v);
y = m + log(sum(exp(v - m)));
end
