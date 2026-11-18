function [bitsHat, info] = turbo_decode(llr, N, R, cfg)
%TURBO_DECODE Turbo 译码统一入口（Toolbox / 本工程实现可切换）
%
%   [bitsHat, info] = turbo_decode(llr, N, R, cfg)
%
%   llr     : 1 x nCoded 编码比特 LLR（ln[P(0)/P(1)]，顺序与 turbo_encode 一致）
%   N       : 信息块长
%   bitsHat : N x 1 信息比特估计
%
% 打孔位置在收端填 0（擦除），交给 comm.TurboDecoder 处理。

engine = resolve_turbo_engine(cfg, R);
llr = llr(:);

switch engine
    case 'toolbox'
        nFull = turbo_toolbox_full_len(N, cfg);
        Lt    = nFull / 3;
        mask  = puncture_mask(Lt, code_rate_index(R, cfg));
        if numel(llr) ~= sum(mask)
            error('turbo_decode: LLR 长度 %d 与打孔图案应保留比特数 %d 不符。', ...
                  numel(llr), sum(mask));
        end
        llrFull = zeros(nFull, 1);
        llrFull(mask) = llr;
        dec = turbo_toolbox_objects('decoder', N, cfg);
        % comm.TurboDecoder 的 LLR 符号约定与本工程相反，故取反
        bitsHat = dec(-llrFull);

        info.engine = 'toolbox';
    otherwise
        [bitsHat, info] = turbo_native_decode(llr, N, R, cfg);
        info.engine = 'native';
end
end
