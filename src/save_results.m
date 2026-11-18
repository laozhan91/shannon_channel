function save_results(cfg, res)
%SAVE_RESULTS 保存全部仿真数据（.mat 与 .csv）
%
%   results/data/sim_results.mat      : 完整结果（含 cfg、香农界、无编码、切换表、自适应）
%   results/data/shannon_bound.csv
%   results/data/uncoded_results.csv
%   results/data/adaptive_results.csv
%   results/data/switch_table.csv

if ~exist(cfg.paths.data, 'dir')
    mkdir(cfg.paths.data);
end

%% ---- 香农界 ----
T = table(res.shannon.snrDb(:), res.shannon.eta(:), ...
          'VariableNames', {'snr_dB', 'eta_bit_per_sym'});
for k = 1:numel(res.shannon.bandwidths)
    T.(sprintf('capacity_kbps_B%d', round(res.shannon.bandwidths(k)))) = ...
        res.shannon.capacityKbps(k, :).';
end
writetable(T, fullfile(cfg.paths.data, 'shannon_bound.csv'));

%% ---- 无编码 ----
T = table(res.snrDb(:), 'VariableNames', {'snr_dB'});
for k = 1:numel(res.uncoded)
    u = res.uncoded(k);
    nm = sprintf('%dQAM', u.M);
    T.([nm '_ber'])         = u.ber(:);
    T.([nm '_berTheory'])   = u.berTheory(:);
    T.([nm '_eta'])         = u.eta(:);
    T.([nm '_nBits'])       = u.bits(:);
    T.([nm '_nErrors'])     = u.errors(:);
end
writetable(T, fullfile(cfg.paths.data, 'uncoded_results.csv'));

%% ---- 自适应 ----
T = table(res.adaptive.snrDb(:), res.adaptive.tier(:), res.adaptive.M(:), ...
          res.adaptive.R(:), res.adaptive.eta(:), res.adaptive.ber(:), ...
          res.adaptive.outage(:), ...
          'VariableNames', {'snr_dB', 'tier', 'M', 'codeRate', 'eta_bit_per_sym', ...
                            'ber', 'outage'});
for k = 1:numel(res.adaptive.bandwidths)
    T.(sprintf('throughput_kbps_B%d', round(res.adaptive.bandwidths(k)))) = ...
        res.adaptive.throughputKbps(k, :).';
end
writetable(T, fullfile(cfg.paths.data, 'adaptive_results.csv'));

%% ---- 切换表 ----
n = numel(res.tbl);
T = table((1:n).', [res.tbl.M].', [res.tbl.R].', [res.tbl.eta].', ...
          [res.tbl.threshold].', [res.tbl.valid].', ...
          'VariableNames', {'index', 'M', 'codeRate', 'eta_bit_per_sym', 'threshold_dB', 'valid'});
T.shannon_dB = shannon_snr_for_eta(T.eta_bit_per_sym);
T.gap_dB     = T.threshold_dB - T.shannon_dB;
writetable(T, fullfile(cfg.paths.data, 'switch_table.csv'));

%% ---- 完整 .mat ----
save(fullfile(cfg.paths.data, 'sim_results.mat'), 'cfg', 'res');

fprintf('  数据已保存：\n');
fprintf('    %s\n', fullfile(cfg.paths.data, 'sim_results.mat'));
fprintf('    %s\n', fullfile(cfg.paths.data, 'shannon_bound.csv'));
fprintf('    %s\n', fullfile(cfg.paths.data, 'uncoded_results.csv'));
fprintf('    %s\n', fullfile(cfg.paths.data, 'adaptive_results.csv'));
fprintf('    %s\n', fullfile(cfg.paths.data, 'switch_table.csv'));
end
