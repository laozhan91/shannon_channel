function cfg = config_params(profile)
%CONFIG_PARAMS 仿真参数集中管理（全项目唯一参数入口）
%
%   cfg = config_params()             % 默认 'balanced' 模式
%   cfg = config_params('fast')       % 快速模式：比特数少、耗时短、精度略降
%   cfg = config_params('accurate')   % 高精度模式：比特数多、耗时长
%
% 说明：
%   1) SNR 定义为 Es/N0，即复基带符号平均功率归一化为 1 时
%      N0 = 10^(-SNR_dB/10)，噪声复方差等于 N0（每个实维方差 N0/2）。
%      因此香农公式 C/B = log2(1 + SNR) 与仿真中的 SNR 完全同口径。
%   2) 有效频谱效率只在 BER <= cfg.targetBER 的 SNR 点成立，否则置 NaN。
%   3) Turbo 码率支持 1/3、1/2、2/3、3/4（母码 1/3 + 打孔）。

if nargin < 1 || isempty(profile)
    profile = 'balanced';
end
cfg.profile = lower(char(profile));

%% ---------------- 1. 基础链路参数 ----------------
cfg.seed          = 20241118;      % 随机种子（全局固定，保证可复现）
cfg.snrRange      = 0:1:30;        % SNR 扫描范围 (dB)，Es/N0
cfg.bandwidths    = [3200 4000];   % 窄带链路带宽 (Hz)：3.2 kHz 与 4 kHz
cfg.targetBER     = 1e-5;          % 有效频谱效率的 BER 门限
cfg.qamOrders     = [4 16 64];     % 固定调制：QPSK / 16-QAM / 64-QAM

%% ---------------- 2. Turbo 码参数 ----------------
cfg.turbo.engine          = 'auto';    % 'auto' | 'native' | 'toolbox'
                                       %   auto    : 有 Communications Toolbox 时用
                                       %             comm.TurboEncoder / comm.TurboDecoder，
                                       %             否则自动改用本工程自带实现
                                       %   native  : 始终使用本工程自带的 PCCC + Log-MAP 实现
                                       %   toolbox : 强制使用 Toolbox（不可用时直接报错）
                                       % 说明：Toolbox 母码固定为 1/3，1/2、2/3、3/4 由本工程
                                       %       在外部打孔、收端填 0 LLR（擦除）实现，性能等价。
cfg.turbo.blockLen        = 1024;      % 信息块长（bit）
cfg.turbo.tailLen         = 3;         % 归零尾比特数（8 状态 RSC）
cfg.turbo.nIter           = 6;         % Turbo 迭代译码次数
cfg.turbo.genPoly         = [13 15];   % RSC 生成多项式（八进制）：反馈 13，前馈 15
cfg.turbo.constraintLen   = 4;         % 约束长度 K=4 -> 8 状态
cfg.turbo.nominalRates    = [1/3 1/2 2/3 3/4];
cfg.turbo.interleaverSeed = 7;         % Turbo 交织器种子（收发两端一致）
cfg.turbo.algorithm       = 'logmap';  % 'logmap'（Log-MAP，无近似）| 'maxlog'（Max-Log-MAP，更快）

%% ---------------- 3. “调制+码率”组合表（切换表候选档位）----------------
% 每行 = [调制阶数 M, 名义码率 R]，净频谱效率 eta = R*log2(M)
cfg.comboTable = [ 4  1/3;    % eta = 0.667  bit/s/Hz  (低 SNR)
                   4  1/2;    % eta = 1.000
                   4  3/4;    % eta = 1.500
                  16  1/2;    % eta = 2.000  (中 SNR)
                  16  2/3;    % eta = 2.667
                  16  3/4;    % eta = 3.000
                  64  2/3;    % eta = 4.000  (高 SNR)
                  64  3/4];   % eta = 4.500

%% ---------------- 4. 仿真规模（按 profile 选择）----------------
switch cfg.profile
    case 'fast'
        cfg.sim.uncodedMinBits   = 2e5;    % 无编码每 SNR 点最少比特
        cfg.sim.uncodedMaxBits   = 1e6;
        cfg.sim.uncodedMaxErrors = 100;
        cfg.sim.adaptiveMinBits  = 3e4;    % 自适应方案每 SNR 点最少比特
        cfg.sim.adaptiveMaxBits  = 1.5e5;
        cfg.sim.adaptiveMaxErrors= 100;
        cfg.calib.minBits        = 4e4;    % 标定每点最少比特
        cfg.calib.maxBits        = 2.5e5;
        cfg.calib.targetErrors   = 20;
    case 'accurate'
        cfg.sim.uncodedMinBits   = 1e6;
        cfg.sim.uncodedMaxBits   = 2e7;
        cfg.sim.uncodedMaxErrors = 300;
        cfg.sim.adaptiveMinBits  = 2e5;
        cfg.sim.adaptiveMaxBits  = 1e6;
        cfg.sim.adaptiveMaxErrors= 300;
        cfg.calib.minBits        = 2e5;
        cfg.calib.maxBits        = 2e6;
        cfg.calib.targetErrors   = 100;
    otherwise   % 'balanced'
        cfg.sim.uncodedMinBits   = 1e6;
        cfg.sim.uncodedMaxBits   = 8e6;
        cfg.sim.uncodedMaxErrors = 200;
        cfg.sim.adaptiveMinBits  = 1e5;
        cfg.sim.adaptiveMaxBits  = 3e5;
        cfg.sim.adaptiveMaxErrors= 100;
        cfg.calib.minBits        = 1e5;
        cfg.calib.maxBits        = 8e5;
        cfg.calib.targetErrors   = 40;
end

%% ---------------- 5. 切换表标定参数 ----------------
cfg.calib.reuseCache     = true;     % 有缓存且参数未变时直接读取，避免重复标定
cfg.calib.coarseStep_dB  = 0.5;      % 粗搜索步长
cfg.calib.fineStep_dB    = 0.25;     % 细化步长（二分一次）
cfg.calib.startOffset_dB = -1.5;     % 搜索起点相对该档香农限的偏移
cfg.calib.searchEnd_dB   = 9.0;      % 搜索终点相对该档香农限的偏移
cfg.calib.margin_dB      = 0.15;     % 门限保护余量（避免边界抖动）

%% ---------------- 6. 路径 ----------------
cfg.paths.root        = fileparts(mfilename('fullpath'));
cfg.paths.src         = fullfile(cfg.paths.root, 'src');
cfg.paths.figures     = fullfile(cfg.paths.root, 'results', 'figures');
cfg.paths.data        = fullfile(cfg.paths.root, 'results', 'data');
cfg.paths.switchTable = fullfile(cfg.paths.data, 'switch_table.mat');
end
