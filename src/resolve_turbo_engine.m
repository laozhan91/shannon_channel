function engine = resolve_turbo_engine(cfg, R)
%RESOLVE_TURBO_ENGINE 决定本次编码/译码使用 Toolbox 还是本工程实现
%
%   'toolbox' : Communications Toolbox 的 comm.TurboEncoder/comm.TurboDecoder
%               （母码 1/3；1/2、2/3、3/4 由本工程在外部打孔/擦除实现，
%                 见 turbo_encode / turbo_decode 说明）
%   'native'  : 本工程自带的 PCCC + Log-MAP 实现（不依赖任何工具箱）
%
% 两者在 BER 性能上一致（由 test_turbo_awgn 第 5 项配对验证）。

mode = lower(cfg.turbo.engine);
hasToolbox = (exist('comm.TurboEncoder', 'class') == 8) && ...
             (exist('comm.TurboDecoder', 'class') == 8) && ...
             logical(license('test', 'Communication_Toolbox'));

switch mode
    case 'native'
        engine = 'native';
    case 'toolbox'
        if ~hasToolbox
            error(['resolve_turbo_engine: 未检测到 Communications Toolbox 的 Turbo 对象，' ...
                   '请把 cfg.turbo.engine 设为 ''native'' 或 ''auto''。']);
        end
        engine = 'toolbox';
    otherwise    % 'auto'
        if hasToolbox
            engine = 'toolbox';
        else
            engine = 'native';
        end
end
end
