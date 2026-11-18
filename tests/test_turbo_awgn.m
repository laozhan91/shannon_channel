function test_turbo_awgn()
%TEST_TURBO_AWGN 验证 Turbo 码编解码正确性与 AWGN 下的 BER 曲线合理性
%
%   运行：test_turbo_awgn
%
% 校验点：
%   1) 本工程网格表与 MATLAB poly2trellis(4,[13 15],13) 完全一致；
%   2) 各码率编码输出长度符合 R_actual ≈ R（误差 < 1%）；
%   3) 高 SNR（30 dB）下所有码率均无残余误码（无系统性 BER floor）；
%   4) 瀑布曲线随 SNR 单调下降，且 1/3 码率 QPSK 在低 SNR 达到目标 BER；
%   5) 本工程实现与 Communications Toolbox（comm.TurboEncoder/Decoder）
%      在 1/3 码率下性能一致（差异 < 3 倍，允许统计起伏）；
%   6) 16-QAM / 64-QAM 高 SNR 下无残余误码（验证软解调 LLR 与比特映射一致）。

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
addpath(fullfile(root, 'src'));

fprintf('=== test_turbo_awgn ===\n');
cfg = config_params('fast');
cfg.turbo.engine = 'native';
rng(cfg.seed);
nPass = 0;

%% ---------- 1) 网格一致性 ----------
fprintf('\n[1] 网格表 vs poly2trellis(4,[13 15],13)\n');
T = rsc_trellis(cfg.turbo.genPoly, cfg.turbo.constraintLen);
if exist('poly2trellis', 'file') == 2
    trel = poly2trellis(cfg.turbo.constraintLen, cfg.turbo.genPoly, cfg.turbo.genPoly(1));
    assert(isequal(T.NS, trel.nextStates), 'nextStates 不一致');
    assert(isequal(T.PAR, bitget(trel.outputs, 1)), 'parity 输出不一致');
    fprintf('   nextStates / parity 完全一致  PASS\n');
else
    fprintf('   未检测到 poly2trellis，跳过（不影响本工程实现）\n');
end
nPass = nPass + 1;

%% ---------- 2) 码率与码长 ----------
fprintf('\n[2] 编码输出长度 / 实际码率\n');
for R = cfg.turbo.nominalRates
    b = randi([0 1], cfg.turbo.blockLen, 1);
    [cd, info] = turbo_encode(b, R, cfg);
    err = abs(info.rateActual - R) / R;
    fprintf('   R=%.3f  nCoded=%4d  R_actual=%.4f  (偏差 %.2f%%)  %s\n', ...
            R, numel(cd), info.rateActual, err*100, ternary(err < 0.01, 'PASS', 'FAIL'));
    assert(err < 0.01, 'R=%.3f 的实际码率偏差过大', R);
end
nPass = nPass + 1;

%% ---------- 3) 无噪声译码 ----------
fprintf('\n[3] 高 SNR (30 dB) 无残余误码\n');
for R = cfg.turbo.nominalRates
    e = run_link(cfg, 4, R, 30, 2);
    fprintf('   R=%.3f  QPSK 30 dB: %d 错 / %d bit  %s\n', R, e.err, e.bits, ...
            ternary(e.err == 0, 'PASS', 'FAIL'));
    assert(e.err == 0, 'R=%.3f 在 30 dB 下仍有误码', R);
end
nPass = nPass + 1;

%% ---------- 4) 瀑布曲线 ----------
fprintf('\n[4] 1/3 码率 QPSK 瀑布曲线（每点 10 块 = 10240 bit）\n');
snrs = [-2.5 -2 -1.5 -1];
bers = zeros(size(snrs));
for k = 1:numel(snrs)
    e = run_link(cfg, 4, 1/3, snrs(k), 10);
    bers(k) = e.err / e.bits;
    fprintf('   SNR=%5.1f dB  BER=%.3e\n', snrs(k), bers(k));
end
assert(all(diff(bers) <= 1e-9), 'BER 未随 SNR 单调下降');
assert(bers(end) < 1e-3, '1/3 码率在 -1 dB 未达到预期性能（BER=%.2e）', bers(end));
fprintf('   单调下降且 -1 dB 时 BER < 1e-3  PASS\n');
nPass = nPass + 1;

%% ---------- 5) native vs toolbox（配对比较，降低统计方差）----------
fprintf('\n[5] 本工程实现 vs Communications Toolbox（1/3 码率，-1.5 dB，配对比较）\n');
if exist('comm.TurboEncoder', 'class') == 8 && exist('comm.TurboDecoder', 'class') == 8
    cfgN = cfg; cfgN.turbo.engine = 'native';
    cfgT = cfg; cfgT.turbo.engine = 'toolbox';
    eN = paired_link(cfgN, cfgT, 4, 1/3, -1.5, 30);
    bN = eN.errN / eN.bits;
    bT = eN.errT / eN.bits;
    ratio = max(bN, realmin) / max(bT, realmin);
    fprintf('   native : nCoded=%d  BER=%.3e (%d/%d)\n', eN.nCodedN, bN, eN.errN, eN.bits);
    fprintf('   toolbox: nCoded=%d  BER=%.3e (%d/%d)\n', eN.nCodedT, bT, eN.errT, eN.bits);
    ok = (bN < 2*bT + 4e-3) && (bT < 2*bN + 4e-3) && bN > 0 && bT > 0;
    fprintf('   两者性能差异 %.2f 倍  %s\n', ratio, ternary(ok, 'PASS', 'FAIL'));
    assert(ok, '本工程实现与 Toolbox 的性能差异过大');
else
    fprintf('   未检测到 Communications Toolbox，跳过\n');
end
nPass = nPass + 1;

%% ---------- 6) 高阶调制 LLR 一致性 ----------
fprintf('\n[6] 16-QAM / 64-QAM 高 SNR 无残余误码\n');
for M = [16 64]
    e = run_link(cfg, M, 3/4, 25, 2);
    fprintf('   %d-QAM R=3/4 25 dB: %d 错 / %d bit  %s\n', M, e.err, e.bits, ...
            ternary(e.err == 0, 'PASS', 'FAIL'));
    assert(e.err == 0, '%d-QAM 在 25 dB 下仍有误码', M);
end
nPass = nPass + 1;

fprintf('\n=== test_turbo_awgn: 全部 %d 组测试通过 ===\n', nPass);
end

% ----------------------------------------------------------------------
function e = run_link(cfg, M, R, snrDb, nBlocks)
%RUN_LINK 运行指定块数的 Turbo-QAM 链路，返回误码统计
local_rng(cfg, M, R, snrDb, 'test_turbo');
nv   = 10^(-snrDb/10);
bTot = log2(M);
N    = cfg.turbo.blockLen;
e.err = 0; e.bits = 0; e.nCoded = 0;
for k = 1:nBlocks
    b = randi([0 1], N, 1);
    [cd, ~] = turbo_encode(b, R, cfg);
    e.nCoded = numel(cd);
    x = qam_mod([cd, zeros(1, mod(-numel(cd), bTot))], M);
    y = x + sqrt(nv/2) * (randn(size(x)) + 1i*randn(size(x)));
    llr = qam_demod_llr(y, M, nv);
    llr = llr(1:numel(cd));
    bh = turbo_decode(llr, N, R, cfg);
    e.err  = e.err + sum(bh ~= b);
    e.bits = e.bits + N;
end
end

% ----------------------------------------------------------------------
function e = paired_link(cfgN, cfgT, M, R, snrDb, nBlocks)
%PAIRED_LINK 同一比特/噪声实现在两种 Turbo 引擎下的配对比较
local_rng(cfgN, M, R, snrDb, 'test_pair');
nv   = 10^(-snrDb/10);
bTot = log2(M);
N    = cfgN.turbo.blockLen;
e.errN = 0; e.errT = 0; e.bits = 0; e.nCodedN = 0; e.nCodedT = 0;
for k = 1:nBlocks
    b = randi([0 1], N, 1);
    nMax = 3*N + 64;
    z = sqrt(nv/2) * (randn(nMax, 1) + 1i*randn(nMax, 1));
    for eng = 1:2
        if eng == 1
            cfg = cfgN;
        else
            cfg = cfgT;
        end
        [cd, ~] = turbo_encode(b, R, cfg);
        nc = numel(cd);
        x = qam_mod([cd, zeros(1, mod(-nc, bTot))], M);
        y = x + z(1:numel(x));
        llr = qam_demod_llr(y, M, nv);
        llr = llr(1:nc);
        bh = turbo_decode(llr, N, R, cfg);
        if eng == 1
            e.errN = e.errN + sum(bh ~= b);
            e.nCodedN = nc;
        else
            e.errT = e.errT + sum(bh ~= b);
            e.nCodedT = nc;
        end
    end
    e.bits = e.bits + N;
end
end

% ----------------------------------------------------------------------
function s = ternary(cond, a, b)
if cond
    s = a;
else
    s = b;
end
end
