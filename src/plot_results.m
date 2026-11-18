function figs = plot_results(cfg, res)
%PLOT_RESULTS 生成三张结果图并保存到 results/figures/
%
%   图1：频谱效率 vs SNR（香农界 / 无编码 QPSK·16QAM·64QAM / 自适应 Turbo-QAM）
%   图2：绝对吞吐量 vs SNR（B = 3.2 kHz 与 4 kHz 的香农界与自适应方案）
%   图3：自适应方案逐 SNR 的调制/码率/净频谱效率（阶梯图）

if ~exist(cfg.paths.figures, 'dir')
    mkdir(cfg.paths.figures);
end
figs = [];

%% ---------------- 图1 频谱效率 ----------------
f1 = figure('Color', 'w', 'Position', [80 80 900 620]);
hold on; grid on; box on;
h = zeros(1, 2 + numel(cfg.qamOrders));
leg = cell(1, numel(h));

h(1) = plot(res.shannon.snrDb, res.shannon.eta, 'k-', 'LineWidth', 2.4);
leg{1} = 'Shannon bound  log_2(1+SNR)';

mk = {'o', 's', '^'};
cl = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];
for k = 1:numel(res.uncoded)
    u = res.uncoded(k);
    % 有效频谱效率是“分段常数”：用阶梯折线画出，NaN 段自动断开
    [xs, ys] = step_curve(u.snrDb, u.eta);
    h(1+k) = plot(xs, ys, '-', 'Color', cl(k,:), 'LineWidth', 2.0);
    v = ~isnan(u.eta);
    plot(u.snrDb(v), u.eta(v), mk{k}, 'Color', cl(k,:), 'MarkerSize', 6, ...
         'MarkerFaceColor', 'w', 'LineWidth', 1.2);
    leg{1+k} = sprintf('Uncoded %s (BER\\leq10^{-5})', mod_name(u.M));
end

h(end) = plot(res.adaptive.snrDb, res.adaptive.eta, '-o', 'Color', [0.75 0.10 0.15], ...
              'LineWidth', 2.2, 'MarkerSize', 6, 'MarkerFaceColor', [0.75 0.10 0.15]);
leg{end} = 'Adaptive Turbo-QAM (AMC)';

yl = [0, max(6, ceil(res.shannon.eta(end)))];
ylim(yl);
xlim([min(res.shannon.snrDb) max(res.shannon.snrDb)]);
xlabel('SNR = E_s/N_0 (dB)');
ylabel('Spectral efficiency \eta (bit/s/Hz)');
title('Spectral efficiency vs SNR: 3.2–4 kHz narrowband AWGN link');
legend(h, leg, 'Location', 'northwest');
set(gca, 'FontSize', 11);

print_fig(f1, cfg, 1, 'spectral_efficiency');
figs(end+1) = f1;

%% ---------------- 图2 绝对吞吐量 ----------------
f2 = figure('Color', 'w', 'Position', [100 100 900 620]);
hold on; grid on; box on;
B = res.shannon.bandwidths;
cl2 = [0.00 0.45 0.74; 0.47 0.67 0.19];
h2 = []; leg2 = {};
for k = 1:numel(B)
    h2(end+1) = plot(res.shannon.snrDb, res.shannon.capacityKbps(k,:), '--', ...
                     'Color', cl2(k,:), 'LineWidth', 2.0);            %#ok<AGROW>
    leg2{end+1} = sprintf('Shannon, B = %.1f kHz', B(k)/1e3);           %#ok<AGROW>
end
for k = 1:numel(B)
    h2(end+1) = plot(res.adaptive.snrDb, res.adaptive.throughputKbps(k,:), '-o', ...
                     'Color', cl2(k,:), 'LineWidth', 2.0, 'MarkerSize', 5, ...
                     'MarkerFaceColor', 'w');                            %#ok<AGROW>
    leg2{end+1} = sprintf('Adaptive Turbo-QAM, B = %.1f kHz', B(k)/1e3); %#ok<AGROW>
end
xlim([min(res.snrDb) max(res.snrDb)]);
xlabel('SNR = E_s/N_0 (dB)');
ylabel('Absolute throughput (kbps)');
title('Absolute throughput vs SNR for B = 3.2 kHz and 4 kHz');
legend(h2, leg2, 'Location', 'northwest');
set(gca, 'FontSize', 11);

print_fig(f2, cfg, 2, 'throughput');
figs(end+1) = f2;

%% ---------------- 图3 自适应选择结果 ----------------
f3 = figure('Color', 'w', 'Position', [120 60 900 760]);

subplot(3,1,1);
stairs(res.adaptive.snrDb, res.adaptive.M, 'LineWidth', 2.0, 'Color', [0.00 0.45 0.74]);
grid on; box on;
set(gca, 'YTick', [4 16 64], 'YTickLabel', {'QPSK', '16-QAM', '64-QAM'});
ylim([0 80]);
ylabel('Modulation');
title('Adaptive Turbo-QAM: selected modulation / code rate / net spectral efficiency');
set(gca, 'FontSize', 10);

subplot(3,1,2);
stairs(res.adaptive.snrDb, res.adaptive.R, 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10]);
grid on; box on;
set(gca, 'YTick', [1/3 1/2 2/3 3/4], 'YTickLabel', {'1/3', '1/2', '2/3', '3/4'});
ylim([0.2 0.9]);
ylabel('Turbo code rate');
set(gca, 'FontSize', 10);

subplot(3,1,3);
hold on; grid on; box on;
stairs(res.adaptive.snrDb, res.adaptive.eta, 'LineWidth', 2.0, 'Color', [0.75 0.10 0.15]);
plot(res.shannon.snrDb, res.shannon.eta, 'k-', 'LineWidth', 1.5);
legend({'Selected \eta', 'Shannon bound'}, 'Location', 'northwest');
ylim([0 max(6, ceil(res.shannon.eta(end)))]);
xlabel('SNR = E_s/N_0 (dB)');
ylabel('Net \eta (bit/s/Hz)');
set(gca, 'FontSize', 10);

print_fig(f3, cfg, 3, 'adaptation');
figs(end+1) = f3;
end

% ----------------------------------------------------------------------
function print_fig(f, cfg, idx, name)
base = fullfile(cfg.paths.figures, sprintf('fig%d_%s', idx, name));
if exist('exportgraphics', 'file') == 2
    exportgraphics(f, [base '.png'], 'Resolution', 200);
else
    saveas(f, [base '.png']);
end
savefig(f, [base '.fig']);
end

% ----------------------------------------------------------------------
function [xs, ys] = step_curve(snr, eta)
%STEP_CURVE 把“分段常数 + NaN 断裂”的数据转成阶梯折线（每段前后各延伸半格）
d = median(diff(snr));
if isempty(d) || ~isfinite(d)
    d = 1;
end
xs = []; ys = [];
k = 1;
n = numel(snr);
while k <= n
    if isnan(eta(k))
        k = k + 1;
        continue;
    end
    j = k;
    while j < n && ~isnan(eta(j+1))
        j = j + 1;
    end
    seg_x = [snr(k)-d/2, snr(k:j), snr(j)+d/2];
    seg_y = [eta(k), eta(k:j), eta(j)];
    if isempty(xs)
        xs = seg_x; ys = seg_y;
    else
        xs = [xs, NaN, seg_x];   %#ok<AGROW>
        ys = [ys, NaN, seg_y];   %#ok<AGROW>
    end
    k = j + 1;
end
end

% ----------------------------------------------------------------------
function s = mod_name(M)
switch M
    case 4,  s = 'QPSK';
    case 16, s = '16-QAM';
    case 64, s = '64-QAM';
    otherwise, s = sprintf('%d-QAM', M);
end
end
