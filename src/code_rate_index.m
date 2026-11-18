function idx = code_rate_index(R, cfg)
%CODE_RATE_INDEX 把名义码率映射为打孔图案编号（1..4）
%
%   1 -> 1/3（不打孔）  2 -> 1/2   3 -> 2/3   4 -> 3/4

rates = cfg.turbo.nominalRates(:).';
[~, idx] = min(abs(rates - R));
if abs(rates(idx) - R) > 1e-9
    error('code_rate_index: 不支持的码率 %.4f，可选值：%s', R, mat2str(rates, 4));
end
end
