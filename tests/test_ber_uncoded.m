function test_ber_uncoded()
%TEST_BER_UNCODED 验证无编码 QPSK / 16-QAM / 64-QAM 的 BER 与理论值一致
%
%   运行：test_ber_uncoded
%
% 校验点：
%   1) QPSK 仿真 BER 与理论 Q(sqrt(Es/N0)) 在统计误差内一致；
%   2) 16-QAM / 64-QAM 与 Gray 映射理论近似式一致（高 SNR 下误差 < 15%）；
%   3) 有效频谱效率门限逻辑正确（BER > 1e-5 时 eta = NaN，达标时 eta = log2(M)）。
%
% 说明（SNR 口径）：
%   本工程 SNR 定义为 Es/N0（符号功率 1，复噪声方差 N0 = 10^(-SNR/10)）。
%   此时 QPSK 精确 BER = Q(sqrt(Es/N0)) = Q(sqrt(SNR))。
%   教科书常见的 qfunc(sqrt(2*SNR)) 形式对应 SNR 取 Eb/N0
%   （QPSK 中 Eb = Es/2，故两者相差 3 dB），二者在这里数值上完全等价：
%       Q(sqrt(2*Eb/N0)) = Q(sqrt(2*(SNR/2))) = Q(sqrt(SNR))

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
addpath(fullfile(root, 'src'));

fprintf('=== test_ber_uncoded ===\n');
cfg = config_params('fast');
cfg.turbo.engine = 'native';
rng(cfg.seed);
nPass = 0;

%% ---------- 1) QPSK vs 理论 ----------
fprintf('\n[1] QPSK：仿真 vs 理论 Q(sqrt(Es/N0))\n');
snrs = [0 4 8 10];
r = simulate_uncoded_qam(cfg, 4, snrs, ...
        struct('minBits', 4e5, 'maxBits', 4e6, 'maxErrors', 400, 'tag', 'test1'));
for k = 1:numel(snrs)
    p   = r.berTheory(k);
    n   = r.bits(k);
    pe  = r.ber(k);
    sig = sqrt(max(p*(1-p)/n, realmin));
    tol = max(4*sig, 0.10*p);
    err = abs(pe - p);
    fprintf('   SNR=%4.1f dB  sim=%.3e  theory=%.3e  |Δ|=%.2e  tol=%.2e  %s\n', ...
            snrs(k), pe, p, err, tol, ternary(err <= tol, 'PASS', 'FAIL'));
    assert(err <= tol, 'QPSK BER 与理论偏差超过统计容限 (SNR=%g dB)', snrs(k));
end
% 等价性：Q(sqrt(2*Eb/N0)) = Q(sqrt(Es/N0))
ebn0 = 10.^(snrs/10)/2;
assert(max(abs(qfun(sqrt(2*ebn0)) - qfun(sqrt(10.^(snrs/10))))) < 1e-12, ...
       'Eb/N0 与 Es/N0 表达式的等价关系不成立');
nPass = nPass + 1;

%% ---------- 2) 16-QAM / 64-QAM ----------
fprintf('\n[2] 16-QAM / 64-QAM：仿真 vs Gray 理论近似式\n');
cases = {16, [12 16], 0.15; 64, [18 22], 0.15};
for ci = 1:size(cases, 1)
    M = cases{ci, 1};
    s = cases{ci, 2};
    tolRel = cases{ci, 3};
    r = simulate_uncoded_qam(cfg, M, s, ...
            struct('minBits', 2e5, 'maxBits', 8e6, 'maxErrors', 400, 'tag', 'test2'));
    for k = 1:numel(s)
        p   = r.berTheory(k);
        n   = r.bits(k);
        pe  = r.ber(k);
        sig = sqrt(max(p*(1-p)/n, realmin));
        tol = max(4*sig, tolRel*p);
        err = abs(pe - p);
        fprintf('   SNR=%4.1f dB  sim=%.3e  theory=%.3e  |Δ|=%.2e  tol=%.2e  %s\n', ...
                s(k), pe, p, err, tol, ternary(err <= tol, 'PASS', 'FAIL'));
        assert(err <= tol, '%d-QAM BER 与理论偏差过大 (SNR=%g dB)', M, s(k));
    end
end
nPass = nPass + 1;

%% ---------- 3) 有效频谱效率门限逻辑 ----------
fprintf('\n[3] 有效频谱效率门限逻辑\n');
r = simulate_uncoded_qam(cfg, 4, [2 16], ...
        struct('minBits', 2e5, 'maxBits', 2e6, 'maxErrors', 200, 'tag', 'test3'));
assert(isnan(r.eta(1)), '低 SNR 点（BER>1e-5）不应计入有效频谱效率');
assert(r.eta(2) == 2, '高 SNR 点（BER<=1e-5）应有 eta = log2(4) = 2');
fprintf('   SNR=2 dB  eta=NaN (BER=%.2e)，SNR=16 dB  eta=%g  PASS\n', r.ber(1), r.eta(2));
nPass = nPass + 1;

fprintf('\n=== test_ber_uncoded: 全部 %d 组测试通过 ===\n', nPass);
end

% ----------------------------------------------------------------------
function s = ternary(cond, a, b)
if cond
    s = a;
else
    s = b;
end
end
