function [par, sEnd] = rsc_encode(u, T, s0)
%RSC_ENCODE RSC 编码（系统比特 = 输入本身，只输出校验比特）
%
%   [par, sEnd] = rsc_encode(u, T)
%   [par, sEnd] = rsc_encode(u, T, s0)    % 从指定初始状态开始（用于归零尾比特）
%
%   u    : L x 1 输入比特
%   par  : L x 1 校验比特
%   sEnd : 编码结束状态

if nargin < 3 || isempty(s0)
    s0 = 0;
end
u = u(:);
L = numel(u);
par = zeros(L, 1);
s = s0;
for k = 1:L
    uu = u(k);
    par(k) = T.PAR(s+1, uu+1);
    s = T.NS(s+1, uu+1);
end
sEnd = s;
end
