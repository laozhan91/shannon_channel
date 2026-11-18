function y = qfun(x)
%QFUN 高斯 Q 函数（避免依赖 Communications Toolbox 的 qfunc）
%   Q(x) = 0.5 * erfc(x / sqrt(2))
y = 0.5 * erfc(x / sqrt(2));
end
