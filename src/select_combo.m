function [tier, sel] = select_combo(tbl, snrDb)
%SELECT_COMBO 按切换表选择当前 SNR 下可用的最高效率档
%
%   [tier, sel] = select_combo(tbl, snrDb)
%
%   tbl   : calibrate_switch_table 产生的结构体数组
%   tier  : 选中的档位索引；0 表示无可用档（链路中断，不发送）
%   sel   : 选中档位的参数（tier=0 时 eta=0, threshold=Inf）

thresholds = [tbl.threshold];
etas       = [tbl.eta];
ok = find(thresholds <= snrDb);
if isempty(ok)
    tier = 0;
    sel.M = []; sel.R = []; sel.eta = 0; sel.threshold = Inf;
else
    [~, j] = max(etas(ok));
    tier = ok(j);
    sel  = tbl(tier);
end
end
