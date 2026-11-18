function [coded, info] = turbo_encode(bits, R, cfg)
%TURBO_ENCODE Turbo 编码统一入口（Toolbox / 本工程实现可切换）
%
%   [coded, info] = turbo_encode(bits, R, cfg)
%
%   bits  : N x 1（或 1 x N）信息比特
%   R     : 名义码率 1/3、1/2、2/3、3/4
%   coded : 1 x nCoded 编码比特
%
% 打孔说明：
%   comm.TurboEncoder 本身不支持打孔，因此本工程在**外部**完成打孔：
%   取其 1/3 母码输出，按 puncture_mask 只发送保留下来的比特。
%   收端在对应位置填入 LLR = 0（擦除）再送入 comm.TurboDecoder，
%   这在数学上完全等价于标准打孔 Turbo 码（见 test_turbo_awgn 的对比）。

engine = resolve_turbo_engine(cfg, R);
N = numel(bits);

switch engine
    case 'toolbox'
        enc    = turbo_toolbox_objects('encoder', N, cfg);
        mother = enc(bits(:)).';                 % 1 x 3*Lt
        Lt     = numel(mother) / 3;
        Ridx   = code_rate_index(R, cfg);
        mask   = puncture_mask(Lt, Ridx);
        coded  = mother(mask);

        info.engine     = 'toolbox';
        info.mask       = mask;
        info.L          = Lt;
        info.nFull      = numel(mother);
        info.nCoded     = numel(coded);
        info.rateActual = N / numel(coded);
    otherwise
        [coded, info] = turbo_native_encode(bits, R, cfg);
        info.engine = 'native';
        info.nFull  = 3 * info.L;
end
end
