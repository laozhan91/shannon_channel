function h = local_rng(varargin)
%LOCAL_RNG 为每个仿真工况生成独立、可复现的随机数流
%
%   h = local_rng(cfg, M, R, snrDb, tagString)
%
% 通过把 (调制阶数, 码率, SNR, 工况标签) 混入全局种子，保证：
%   1) 每次运行结果完全一致（可复现）；
%   2) 不同工况之间互不相关，不受仿真顺序影响。

cfg    = varargin{1};
M      = varargin{2};
R      = varargin{3};
snrDb  = varargin{4};
if numel(varargin) >= 5
    tag = varargin{5};
else
    tag = '';
end
tagHash = 0;
for k = 1:numel(tag)
    tagHash = mod(tagHash*131 + double(tag(k)), 2147483647);
end

MAXINT = 2147483647;                                  % 2^31-1
h = mod(cfg.seed, MAXINT);
h = mod(h + 7919*round(log2(M)), MAXINT);
h = mod(h + 104729*round(1000*R), MAXINT);
h = mod(h + 1299709*round(100*(snrDb + 60)), MAXINT);
h = mod(h + tagHash, MAXINT);
rng(h);
end
