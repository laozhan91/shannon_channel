function obj = turbo_toolbox_objects(kind, N, cfg)
%TURBO_TOOLBOX_OBJECTS 创建（并缓存）Communications Toolbox 的 Turbo 对象
%
%   obj = turbo_toolbox_objects('encoder', N, cfg)
%   obj = turbo_toolbox_objects('decoder', N, cfg)
%
% 说明：comm.TurboEncoder/comm.TurboDecoder 采用与 3GPP LTE 相同的 8 状态
% RSC（poly2trellis(4,[13 15],13)）与母码 1/3 结构，但**不支持打孔**，
% 因此只在 1/3 码率下使用；其余码率由 turbo_native_encode/decode 完成。

persistent cachedN cachedIter cachedEnc cachedDec
if isempty(cachedN) || cachedN ~= N || cachedIter ~= cfg.turbo.nIter
    trel = poly2trellis(cfg.turbo.constraintLen, cfg.turbo.genPoly, cfg.turbo.genPoly(1));
    idx  = turbo_perm(N, cfg.turbo.interleaverSeed);
    idx  = idx(:);
    cachedEnc = comm.TurboEncoder('TrellisStructure', trel, 'InterleaverIndices', idx);
    cachedDec = comm.TurboDecoder('TrellisStructure', trel, 'InterleaverIndices', idx, ...
                                  'NumIterations', cfg.turbo.nIter);
    cachedN = N;
    cachedIter = cfg.turbo.nIter;
end

switch lower(kind)
    case 'encoder'
        obj = cachedEnc;
    case 'decoder'
        obj = cachedDec;
    otherwise
        error('turbo_toolbox_objects: 未知类型 %s', kind);
end
end
