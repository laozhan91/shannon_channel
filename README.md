# 3.2–4 kHz 窄带链路：自适应 Turbo 编码 QAM（AMC-Turbo-QAM）与香农界对比仿真

在 AWGN 复基带信道下，对比三类方案的**频谱效率–SNR** 与**绝对吞吐量–SNR** 曲线：

1. **香农界**：`C/B = log2(1+SNR)`，并换算到 `B = 3200 Hz` 与 `B = 4000 Hz` 的绝对容量；
2. **固定调制无编码**：QPSK / 16-QAM / 64-QAM（Gray 映射），只有实测 `BER ≤ 1e-5` 的 SNR 点才计入有效频谱效率；
3. **自适应 Turbo-QAM（AMC）**：按 SNR 在 8 档「调制 + Turbo 码率」之间切换，统计净频谱效率与实际吞吐量。

全部代码在 MATLAB R2024b 上实测可直接运行（Communications Toolbox 存在时自动启用，缺失时自动降级）。

---

## 1. 目录结构

```
shannon_channel/
├── README.md                    项目说明（本文件）
├── main_simulation.m            主入口：一键跑完 5 个步骤并出图、存数据
├── config_params.m              参数集中管理（带宽、SNR 范围、目标 BER、Turbo 参数、切换表）
├── run_main.bat                 PowerShell/cmd 一键运行（等价于 matlab -batch "main_simulation"）
├── run_tests.bat                PowerShell/cmd 一键运行两个测试脚本
├── src/
│   ├── shannon_bound.m          香农界：频谱效率 + 绝对容量（bps / kbps）
│   ├── shannon_snr_for_eta.m    香农界反函数：给定 eta 求最小 SNR（dB）
│   ├── simulate_uncoded_qam.m   固定调制无编码 BER 蒙特卡洛仿真（chunk 累加、按误差数提前停止）
│   ├── ber_uncoded_theory.m     无编码方形 QAM 理论 BER（Gray 映射近似式）
│   ├── calibrate_switch_table.m 标定 SNR → (调制, 码率) 切换表（含缓存）
│   ├── adaptive_amc_sim.m       自适应 Turbo-QAM 单 SNR 点仿真（选档 + 实测 BER + 吞吐量）
│   ├── simulate_turbo_link.m    Turbo-QAM 链路单点蒙特卡洛仿真（编码→调制→AWGN→软解调→译码）
│   ├── turbo_encode.m           Turbo 编码统一入口（Toolbox / 自研实现自动切换）
│   ├── turbo_decode.m           Turbo 译码统一入口
│   ├── turbo_native_encode.m    自研 PCCC 编码器（母码 1/3 + 打孔 1/3,1/2,2/3,3/4）
│   ├── turbo_native_decode.m    自研迭代译码器（Log-MAP，6 次迭代，支持反打孔）
│   ├── logmap_decode_rsc.m      单分量 BCJR（Log-MAP / Max-Log-MAP）
│   ├── rsc_trellis.m            8 状态 RSC 网格表（与 poly2trellis(4,[13 15],13) 一致）
│   ├── rsc_encode.m              RSC 编码
│   ├── rsc_terminate.m           递归码归零尾比特计算
│   ├── puncture_mask.m           母码打孔图案
│   ├── code_rate_index.m         码率 → 打孔图案编号
│   ├── turbo_perm.m              Turbo 交织器（固定种子、收发一致）
│   ├── turbo_toolbox_objects.m   comm.TurboEncoder/Decoder 对象缓存
│   ├── turbo_toolbox_full_len.m  Toolbox 母码输出长度
│   ├── resolve_turbo_engine.m    引擎选择（auto/native/toolbox）
│   ├── qam_constellation.m       Gray 映射方形 QAM 星座 + 比特表
│   ├── qam_mod.m                 调制
│   ├── qam_demod_hard.m          硬判决解调（可分离判决，O(K)）
│   ├── qam_demod_llr.m           精确软解调（log-sum-exp，输出 LLR）
│   ├── qfun.m                    Q 函数（不依赖工具箱）
│   ├── local_rng.m               逐工况可复现随机流
│   ├── params_fingerprint.m      标定缓存指纹（参数变化自动重标定）
│   ├── select_combo.m            按切换表选档
│   ├── plot_results.m            生成图 1/2/3 并保存 PNG+FIG
│   ├── save_results.m            保存 .mat 与 4 个 .csv
│   └── opt_get.m                 结构体可选参数读取
├── results/
│   ├── figures/                 fig1_spectral_efficiency.{png,fig}
│   │                            fig2_throughput.{png,fig}
│   │                            fig3_adaptation.{png,fig}
│   └── data/                    sim_results.mat, shannon_bound.csv,
│                                uncoded_results.csv, adaptive_results.csv,
│                                switch_table.csv, switch_table.mat（标定缓存）
└── tests/
    ├── test_ber_uncoded.m       验证无编码 QPSK/16-QAM/64-QAM BER 与理论一致
    └── test_turbo_awgn.m        验证 Turbo 编码/译码正确性与 AWGN 下 BER 曲线合理
```

---

## 2. 快速开始

> ⚠️ `main_simulation` 是 **MATLAB 函数**，必须先在 MATLAB 里执行。在 PowerShell / cmd 里直接敲
> `main_simulation` 会报「无法将 ... 识别为 cmdlet、函数、脚本文件或可运行程序的名称」。
> 三种启动方式任选其一：

**方式 A：MATLAB 图形界面（推荐）**

```matlab
% 在 MATLAB 命令行窗口执行（先 cd 到项目根目录）
cd('C:\Users\12628\Desktop\shannon_channel')
main_simulation
```

**方式 B：在 PowerShell / cmd 中调用 MATLAB（`matlab -batch` 会继承当前目录）**

```powershell
cd C:\Users\12628\Desktop\shannon_channel
matlab -batch "main_simulation"
```

**方式 C：批处理脚本（双击即可，失败时暂停显示报错）**

```powershell
.\run_main.bat        # 等价于方式 B
.\run_tests.bat       # 运行两个测试脚本
```

其它用法（在 MATLAB 中）：

```matlab
main_simulation('fast');            % 快速验证（约 1 分钟，比特数少、精度略降）
main_simulation('accurate');        % 高精度（比特数更多，耗时最长）
main_simulation('balanced', true);  % 忽略缓存，强制重新标定切换表
```

运行测试（在 MATLAB 中，项目根目录执行）：

```matlab
addpath(fullfile(pwd,'tests'))
test_ber_uncoded
test_turbo_awgn
```

**运行环境**：MATLAB R2024b（R2019b 及以上均可，代码未使用工具箱专属语法）。
Communications Toolbox 可选（见第 8 节降级方案）。

---

## 3. 本次实测结果摘要（balanced 档）

### 3.1 标定得到的切换表（目标 BER ≤ 1e-5）

| 档位 | 调制 | 码率 | 净频谱效率 η | 门限 SNR (dB) | 该 η 的香农限 (dB) | 与香农界差距 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | QPSK | 1/3 | 0.667 | −0.16 | −2.31 | 2.15 dB |
| 2 | QPSK | 1/2 | 1.000 | 1.90 | 0.00 | 1.90 dB |
| 3 | QPSK | 3/4 | 1.500 | 5.52 | 2.62 | 2.90 dB |
| 4 | 16-QAM | 1/2 | 2.000 | 7.67 | 4.77 | 2.90 dB |
| 5 | 16-QAM | 2/3 | 2.667 | 10.43 | 7.28 | 3.15 dB |
| 6 | 16-QAM | 3/4 | 3.000 | 11.10 | 8.45 | 2.65 dB |
| 7 | 64-QAM | 2/3 | 4.000 | 15.16 | 11.76 | 3.40 dB |
| 8 | 64-QAM | 3/4 | 4.500 | 16.75 | 13.35 | 3.40 dB |

> **与香农界的差距：平均 2.81 dB（最小 1.90 dB，最大 3.40 dB）。**
> 差距来源：① 方形 QAM + 独立比特映射（BICM）相对高斯输入的信道容量损失（约 1~2 dB）；
> ② 8 状态短码、块长仅 1024 bit、6 次迭代的编码增益损失（约 0.5~1 dB）；
> ③ 打孔构造的高码率（3/4）离最优码更远。

### 3.2 各方案对比（净频谱效率，bit/s/Hz；`--` 表示该 SNR 下 BER 未达 1e-5）

| SNR (dB) | 香农界 | 无编码 QPSK | 无编码 16-QAM | 无编码 64-QAM | 自适应 Turbo-QAM |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 6  | 2.32 | -- | -- | -- | **1.50** |
| 12 | 4.07 | -- | -- | -- | **3.00** |
| 18 | 6.00 | 2.00 | -- | -- | **4.50** |
| 24 | 7.98 | 2.00 | 4.00 | -- | **4.50** |

- 无编码固定调制要到 **QPSK 13 dB / 16-QAM 20 dB / 64-QAM 26 dB** 才满足 1e-5，因此在中低 SNR 段完全不可用；
- 自适应方案在 12 dB 就达到 3.0 bit/s/Hz，是任何单一固定调制在该 SNR 下都无法实现的；
- 18 dB 时自适应方案（4.5）是 QPSK 无编码（2.0）的 2.25 倍；
- 自适应各 SNR 点的实测 BER 全为 0（每点至少 1e5 bit 未观察到错误），说明切换门限的保护余量足以保证 1e-5。

### 3.3 绝对吞吐量（kbps）

| SNR (dB) | B = 3.2 kHz | B = 4.0 kHz | 香农界 (3.2 kHz) | 香农界 (4.0 kHz) |
|:---:|:---:|:---:|:---:|:---:|
| 6  | 4.8 | 6.0 | 7.4 | 9.3 |
| 12 | 9.6 | 12.0 | 13.0 | 16.3 |
| 18 | 14.4 | 18.0 | 19.2 | 24.0 |
| 24 | 14.4 | 18.0 | 25.5 | 31.9 |

> 自适应方案的最高档为 64-QAM 3/4（η = 4.5），因此高 SNR 段曲线饱和在 14.4 / 18.0 kbps。
> 若要继续逼近香农界，需要在组合表中加入更高阶调制（256-QAM）或更高码率（5/6、8/9）。

---

## 4. 参数说明（`config_params.m`）

| 参数 | 含义 | 默认值 |
|---|---|---|
| `cfg.seed` | 全局随机种子（保证结果可复现） | `20241118` |
| `cfg.snrRange` | SNR 扫描范围，单位 dB（**Es/N0**） | `0:1:30` |
| `cfg.bandwidths` | 窄带链路带宽 | `[3200 4000]` Hz |
| `cfg.targetBER` | 有效频谱效率的 BER 门限 | `1e-5` |
| `cfg.qamOrders` | 固定调制阶数 | `[4 16 64]` |
| `cfg.turbo.blockLen` | Turbo 信息块长 | `1024` bit |
| `cfg.turbo.nIter` | 迭代译码次数 | `6` |
| `cfg.turbo.nominalRates` | 支持的码率 | `[1/3 1/2 2/3 3/4]` |
| `cfg.turbo.algorithm` | `'logmap'`（精确）/`'maxlog'`（更快、差约 0.3 dB） | `'logmap'` |
| `cfg.turbo.engine` | `'auto'`/`'native'`/`'toolbox'` | `'auto'` |
| `cfg.comboTable` | 切换表候选档位 `[M, R]` | 8 档（见上表） |
| `cfg.sim.uncodedMinBits` | 无编码每 SNR 点**最少**比特数 | `1e6` |
| `cfg.sim.uncodedMaxErrors` | 误码数达到该值即停止 | `200` |
| `cfg.calib.*` | 标定步长、搜索窗、保护余量 | 0.5 / 0.25 dB，余量 0.15 dB |

**常用修改方式**

- 改带宽：`cfg.bandwidths = [3200 4000 8000];`（吞吐量、图 2 会自动增加曲线）；
- 改目标 BER：`cfg.targetBER = 1e-4;` → 切换门限整体前移（需加 `forceRecalibrate` 重新标定）；
- 加档位：在 `cfg.comboTable` 里追加行（如 `[256 3/4]`），改完参数后标定缓存会自动失效；
- 改 SNR 粒度：`cfg.snrRange = 0:0.5:30;`。

---

## 5. 模型与算法

### 5.1 信号模型与 SNR 口径（重要）

复基带：`y = x + n`，`E[|x|²] = 1`，`n ~ CN(0, N0)`，`N0 = 10^(-SNR_dB/10)`。

- 每符号平均功率归一化为 1（QPSK/16-QAM/64-QAM 均如此）；
- **SNR 定义为 Es/N0**，与香农公式 `C/B = log2(1+SNR)` 同口径，因此曲线可直接比较；
- 复数噪声用 `sqrt(N0/2)*(randn + 1i*randn)` 生成（每实维方差 N0/2）。

> ⚠️ 关于 `qfunc(sqrt(2*SNR))`：该式成立于 **SNR ≡ Eb/N0** 的场合。本工程 SNR ≡ Es/N0，
> QPSK 的精确 BER 为 `Q(sqrt(Es/N0)) = Q(sqrt(SNR))`。两者在数值上完全等价：
> `Q(sqrt(2*Eb/N0)) = Q(sqrt(2*(SNR/2))) = Q(sqrt(SNR))`，只是「SNR」的定义相差 3 dB。
> `tests/test_ber_uncoded.m` 同时校验了这两种写法的一致性。

### 5.2 调制与软解调

- 方形 QAM，Gray 映射，按 `M = 4, 16, 64` 构造星座与比特表（`qam_constellation.m`）；
- 硬判决用可分离的 PAM 最近点判决（O(K)，用于无编码大比特量仿真）；
- Turbo 链路用**精确**软解调：
  `L(b_j) = log Σ_{x: b_j=0} exp(-|y-x|²/N0) − log Σ_{x: b_j=1} exp(-|y-x|²/N0)`，
  约定 `L = ln[P(0)/P(1)]`（`qam_demod_llr.m`）。

### 5.3 Turbo 码

- 结构：8 状态 RSC（3GPP LTE 分量码，与 `poly2trellis(4,[13 15],13)` 的网格一致）+ 伪随机交织 + 并行级联，**母码 1/3**；
- 信息块 1024 bit + 归零尾比特；反馈寄存器用 `rsc_terminate.m` 计算归零序列（递归码不能直接补 0）；
- **打孔图案**（`puncture_mask.m`，系统位始终发送）：

| 码率 | 每个时刻保留的校验位 | 校验位占比 |
|---|---|---|
| 1/3 | p1 和 p2 全保留 | 2/2 |
| 1/2 | k 偶 → p1，k 奇 → p2 | 1/2 |
| 2/3 | k≡0 (mod 4) → p1，k≡2 → p2 | 1/2 |
| 3/4 | k≡0 (mod 6) → p1，k≡3 → p2 | 1/3 |

- **译码**：Log-MAP（max* 修正）BCJR，6 次迭代；反打孔时被打孔比特置 LLR = 0（擦除）；
  分量 1 按归零结尾初始化后向度量，分量 2 按“终止状态未知”初始化。
- **引擎选择**：
  - `auto`（默认）：若存在 Communications Toolbox，则用 `comm.TurboEncoder`/`comm.TurboDecoder`
    取 1/3 母码输出，**在外部完成打孔**（收端把被删比特的 LLR 置 0 再送入译码器），
    对所有码率都生效；否则自动使用自研实现。
  - 两条路径在相同比特/噪声下 BER 差异 < 5%（`test_turbo_awgn` 第 5 项配对验证），
    自研实现的网格与 `poly2trellis` 完全一致（第 1 项验证）。

### 5.4 自适应切换表标定（`calibrate_switch_table.m`）

对每个候选档位（调制 M、码率 R，η = R·log2 M）：

1. 从该 η 的香农限 −1.5 dB 开始，按 0.5 dB 步进提高 SNR；
2. 每点做蒙特卡洛 BER 仿真（达标前误码数达到 40 即停，达标点至少 1e5 bit）；
3. 找到第一个 `BER ≤ 1e-5` 的 SNR，再二分细化 0.25 dB；
4. 门限 = 该实测达标点 + 0.15 dB 保护余量；
5. 单调化：η 越高，门限不得低于低效率档。

标定结果带参数指纹缓存到 `results/data/switch_table.mat`，改动物理参数后自动重新标定。

### 5.5 频谱效率与吞吐量

- 无编码固定调制：`η = log2(M)`，仅当实测 `BER ≤ 1e-5` 时有效，否则记 `NaN`（图中断开）；
- 自适应方案：`η = R·log2(M)`（净频谱效率，已扣除编码冗余）；
- 吞吐量：`C = B·η`，图中单位 kbps（`B` 取 3200 / 4000 Hz）；
- 实际码率（含尾比特与打孔开销）也会输出：例如 R=1/3 时为 0.3324，与名义值相差 0.3%，
  图中按题目要求使用名义码率。

---

## 6. 结果图解读

| 图 | 文件 | 解读要点 |
|---|---|---|
| 图 1 | `results/figures/fig1_spectral_efficiency.png` | 黑实线为香农界；三条阶梯线为无编码 QPSK/16-QAM/64-QAM（只在 BER ≤ 1e-5 的 SNR 段出现，因此高 SNR 才是水平线）；红点为自适应 Turbo-QAM。自适应曲线全程位于香农界下方、且在 6~18 dB 段明显高于任何固定调制。 |
| 图 2 | `results/figures/fig2_throughput.png` | 虚线为 B = 3.2/4 kHz 的香农容量，实线为自适应方案的实际吞吐量；两者随 SNR 同步上升，高 SNR 段自适应曲线饱和于 14.4/18.0 kbps（最高档 η = 4.5）。 |
| 图 3 | `results/figures/fig3_adaptation.png` | 上：实际选用的调制（QPSK → 16-QAM → 64-QAM）；中：Turbo 码率随 SNR 的切换（不同调制下会回落到较低码率以换取可靠度）；下：净频谱效率与香农界的相对位置。 |

---

## 7. 与香农界的定量结论

1. **单档位差距**：8 个档位与各自香农限的差距为 **1.90 ~ 3.40 dB**，平均 **2.81 dB**；
   低码率档（η ≤ 2）约 1.9 ~ 2.9 dB，高码率/高阶调制档约 3.1 ~ 3.4 dB。
2. **整体曲线**：在 0~17 dB，自适应曲线与香农界基本保持 2~3 dB 的平行间距；
   17 dB 以后受最高档（64-QAM 3/4）限制而饱和，差距随 SNR 增大而扩大（这是档位表上限而非方案本身的损失）。
3. **相对固定调制的增益**：达到相同频谱效率所需的 SNR 降低 **7~13 dB**（例如 η = 2 bit/s/Hz：
   无编码 16-QAM 需 20 dB，自适应方案 8 dB）；在 12 dB 时自适应方案已可实现 3.0 bit/s/Hz，
   而任何单一无编码调制都无法满足 1e-5。
4. **与理论极限的剩余空间**：约 2.8 dB 中，约 1~2 dB 来自 BICM（方形 QAM + 独立比特映射）的容量损失，
   其余来自短块长（1024 bit）、8 状态码与 6 次迭代。改用更长的块、更好的交织器（QPP）、
   8~10 次迭代可再压缩约 0.5 dB。

---

## 8. 工具箱不可用时的降级方案

| 依赖 | 有工具箱 | 无工具箱（自动降级） |
|---|---|---|
| Turbo 编/译码 | `comm.TurboEncoder` / `comm.TurboDecoder`（母码 1/3，外部打孔） | `turbo_native_encode.m` / `turbo_native_decode.m`：自研 PCCC + Log-MAP BCJR，功能完全等价，速度约慢 10 倍 |
| `poly2trellis` | 用于一致性校验 | 跳过该校验（`rsc_trellis.m` 自带网格表） |
| `qfunc` | — | `src/qfun.m`（基于 `erfc`） |
| `qammod` / `qamdemod` | — | 自研 `qam_mod.m` / `qam_demod_*.m`（Gray 映射，含精确 LLR） |

强制使用自研实现（用于验证或没有工具箱的环境）：

```matlab
cfg = config_params(); cfg.turbo.engine = 'native';   % 或在 config_params.m 中改默认值
```

此时 `main_simulation` 依然可以完整跑通，只是耗时明显增加（balanced 档约 15~25 分钟），
建议配合 `main_simulation('fast')` 使用。

---

## 9. 测试说明

```matlab
cd tests
test_ber_uncoded     % 3 组测试
test_turbo_awgn      % 6 组测试
```

`test_ber_uncoded.m`
1. QPSK 在 0/4/8/10 dB 的仿真 BER 与 `Q(sqrt(Es/N0))` 在 4σ 容限内一致；
2. 16-QAM（12/16 dB）、64-QAM（18/22 dB）与 Gray 理论近似式偏差 < 15%；
3. 门限逻辑：BER > 1e-5 时 η = NaN，达标时 η = log2(M)。

`test_turbo_awgn.m`
1. 自研网格与 `poly2trellis(4,[13 15],13)` 的 `nextStates`、`outputs` 完全一致；
2. 四种码率的实际码率与名义值偏差 < 1%（0.29%~0.34%，来自尾比特）；
3. 30 dB 下四种码率均无残余误码（无 BER floor）；
4. 1/3 码率 QPSK 的瀑布曲线随 SNR 单调下降，−1 dB 时 BER < 1e-3；
5. 自研实现与 Communications Toolbox 的**配对**对比 BER 差异 < 5%；
6. 16-QAM / 64-QAM 在 25 dB 下无残余误码（验证软解调 LLR 与比特映射一致）。

---

## 10. 常见问题

**Q1：为什么无编码 QPSK 要到 13 dB 才「达标」？**
QPSK 在 Es/N0 下的 BER = `Q(sqrt(SNR))`，令其为 1e-5 得 SNR ≈ 12.6 dB。这是 1e-5 这个苛刻门限决定的。

**Q2：为什么 BICM 的曲线在低 SNR 段是 `--`？**
题目要求「只有 BER ≤ 1e-5 的点才计入有效频谱效率」，其余点记为 NaN 并在图中断开。

**Q3：切换表里为什么同一调制下码率先升后降？**
门限是「按效率从低到高」单调化的，跨调制时低码率的 16-QAM 可能比高码率的 QPSK 更早可用，
所以图 3 中间的码率曲线会出现台阶式回落，这是自适应选档的正常现象。

**Q4：结果能否复现？**
可以。所有随机流由 `local_rng.m` 用 `(种子, M, R, SNR, 工况)` 派生，`rng` 状态与仿真顺序无关；
切换表带参数指纹缓存，重新运行会得到完全相同的曲线。

**Q5：想跑得更快？**
`main_simulation('fast')`（约 1 分钟）。若已有标定缓存，`main_simulation` 会跳过标定（约 40 秒完成其余部分）。
