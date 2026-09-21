# 4×4 VectorCGRA NoC 优化实验记录

本文件是实验全过程的统一记录。方案见 `OPTIMIZATION_PLAN.md`；精简测量数据放在 `results/`，原始大文件和工具日志留在忽略的 `build/`、`tools/` 中。未运行、失败、停止与通过分别记录。

## 本轮结果

本轮计划内的实现、筛选、完整综合、时序诊断及最终整机重播已完成。最终 RTL 版本为 `e91686f`（B+C2）。

| 版本 | 完整 CGRA 面积（Liberty 单位） | 映射单元数 | 相对 A0 面积变化 | 可信整机频率 |
|---|---:|---:|---:|---|
| A0 原始实现 | 3,272,792.978 | 2,063,725 | — | 不可用 |
| B1 控制环静态选择 | 2,104,402.342 | 1,206,277 | −35.7001% | 不可用 |
| C2 最终 B+C2 | **2,049,466.692** | **1,160,207** | **−37.3787%** | 不可用 |

最终比 B1 再减少 54,935.650 面积（2.6105%）；相对 A0 减少 43.7809% 映射单元。三版均有 149,369 个 DFF，存储容量、流水边界与接口没有因优化削减。

**面积下降已得到统一流程的整机数据支持；尚不能确认“面积下降且最高频率上升”的双目标。** 三版全网表都存在相同的 8800 个未知组合门输入，至少常量队列 clear 的未知输入可达真实 FF 终点。整机延迟/频率因此留空，不用局部 ABC 延迟替代。库、工具、BUF_X1 驱动、5 fF 负载和层次映射口径一致；这里也不声称物理布局布线后的面积或签核 Fmax。

最终实现采用 B 的控制环静态消息选择和单项 C2 的 prologue 比较共享。C1 条件共享、C3 输入需求译码保留补丁与局部数据供后续选择，没有默认纳入最终版本；未设数值提升门槛。

最终验证：12 项限定回归通过；组件等价证明通过；完整 CGRA 的 INC、四边通信、多播和 prologue 三场景共 **557 cycles / 1114 snapshots** 逐位一致。RTLIR 翻译与 Yosys 检查通过，但本机 `--test-verilog` 在 Verilator 启动阶段失败，不能称为导入构建通过。没有运行耗时数小时的完整 CI；有限整机测试也不等同于所有程序的整机形式证明。

### 完整 CGRA 面积来源

| 部分 | A0 面积 | 最终面积 | 最终占比 |
|---|---:|---:|---:|
| 配置控制环 | 1,799,792.176 | 632,451.442 | 30.86% |
| Tile FU 计算 | 454,655.712 | 454,655.712 | 22.18% |
| Tile 寄存器簇 | 372,783.040 | 372,783.040 | 18.19% |
| Tile 控制存储 | 230,419.840 | 230,419.840 | 11.24% |
| CGRA controller | 102,897.046 | 102,482.086 | 5.00% |
| Tile routing crossbar | 125,747.776 | 81,681.152 | 3.99% |
| 数据存储 | 65,778.608 | 65,778.608 | 3.21% |
| Tile 通道与 LinkOr | 39,921.280 | 39,921.280 | 1.95% |
| Tile 常量存储 | 30,460.192 | 30,460.192 | 1.49% |
| Tile FU crossbar | 37,533.664 | 26,029.696 | 1.27% |
| Tile 其他逻辑 | 11,035.808 | 11,035.808 | 0.54% |
| 顶层其他逻辑 | 1,767.836 | 1,767.836 | 0.09% |

分类由同一完整网表逐实例归属，精确相加等于总面积；占比显示值有舍入。controller 的小幅变化在后文单独审计，不将同一 RTL 的映射波动归因为源码优化。

## 实验约束与版本

- 用户于 2026-09-17 确认计划，并要求使用 Git 分阶段管理、记录子智能体和所有修改。
- 基线：`41cb0c0e94d9373dbb967cb69baa38990d0f402e`。
- 工作分支：`codex/noc-4x4-opt`；17:28 左右创建，创建前已跟踪文件无修改。
- 不增加延迟、不降低吞吐、不删减功能；保持全部合法配置及对外逐周期行为。PPA 只统计结果，不设提升门槛。
- 测量实例采用 `test_vector_mesh_4x4` 参数，直接翻译 DUT。四边接口保留；与原测试一致，`is_multi_cgra=False`，外部 inter-CGRA 网络端口在此实例未启用。
- 所有时间均为本地 Asia/Shanghai。未保存精确时间的早期工作仅记录阶段，不补造时间。

## 子智能体登记与分工

这三个子智能体在计划确认前的准备阶段创建；确认后复用同一子智能体继续分配有边界的任务，未创建额外用户任务。

| 子智能体 | 初始任务 | 确认计划后的任务 | 修改权限 |
|---|---|---|---|
| `/root/noc_contract` | 互连/周期语义只读检查；crossbar 差分和形式验证流程 | 完整 CGRA 逐周期差分，集成/翻译验证 | 验证脚本，不修改 RTL |
| `/root/synth_tools` | 安装官方 Yosys/ABC、sv2v；小网表时序试验 | 全 CGRA 网表诊断、统一 ABC 延迟估计 | 时序脚本及其产物 |
| `/root/area_report` | 面积分解脚本和热点定位 | 独立审核基线；实现 B 的 Switch；在隔离目录评估 C 候选 | B 的 Switch/Cgra 注入及测试；C 原型先限于 `build/` |
| 主智能体 `/root` | 澄清、协调、建立基线 | 分支/提交、实验日志、独立复核、集成及最终报告 | 统一管理，共享文件不并发编辑 |

子智能体使用继承的模型设置。没有向仓库外发送消息或创建 PR。

## E00：计划确认前的准备与暂停

### 环境与新增文件

- 工作区建立 `sys_lib/.venv`，Python 3.12.13。
- 自定义 PyMTL3 fork 固定到 `6db7736ec52e19cbcfc4adeb7868cae890316591`；其余依赖在 `requirements-lock.txt`。
- 按仓库 `.gitmodules` 初始化子模块；没有修改子模块内容或提交指针。
- 官方 OSS CAD Suite 2026-09-16，Yosys `0.69+62 / 0edda7a3a-dirty`，随附 ABC 1.01；sv2v 0.0.13。工具仅安装到 `sys_lib/tools/`。
- 复用事先已有的 `sys_lib/lib/NangateOpenCellLibrary_typical.lib`。来源和校验信息见 `LIBRARY.md`；原文件保留，未纳入 Git。
- 新增准备脚本：`generate.py`、`synthesize.py`、`area_report.py`、`mapped_timing.py`、`verify_crossbar.py`、`equivalence.py`。当时未修改任何 RTL。

### 已运行

```powershell
sys_lib/.venv/Scripts/python.exe sys_lib/generate.py --output sys_lib/build/baseline
sys_lib/.venv/Scripts/python.exe sys_lib/synthesize.py --input sys_lib/build/baseline --mode hierarchical
sys_lib/.venv/Scripts/python.exe sys_lib/area_report.py sys_lib/build/baseline/hierarchical/mapped.json --liberty sys_lib/lib/NangateOpenCellLibrary_typical.lib --top VectorCGRA4x4 --output sys_lib/build/baseline/hierarchical/area
sys_lib/.venv/Scripts/python.exe -m pytest noc/test/CrossbarRTL_test.py -q --tb=short
```

- 基线 RTL 生成成功：1,043,586 bytes；sha256 `f6563fc5518fb2a42c39778529cf28c92ed3477c52a830a76486fd3ae80710d3`。
- 基线分层映射耗时 411.03 s，总面积 3,272,792.978 Liberty 面积单位、2,063,725 单元。分解结果与 Yosys stat 精确一致。
- 控制环占 54.99%；51 个 6×199-bit Mux 占整机 38.76%。这是当前映射成本，不能直接视为可节省面积。
- 现有 Crossbar 两个测试通过。
- 差分流程自检：routing8x8 846 cycles、fu2x8 846、single1x1 134、irregular3x5 502；均为基线对基线，不代表修改后验证。
- Yosys 等价流程自检：routing8x8 1698 点/200 状态位、fu2x8 1006 点/56 状态位通过；无输入假设。报告在 `build/equivalence/equivalence_report.json`。
- 时序方法只在小型跨层网表自检成功：74 cells，418.62 ps。不是 CGRA 结果。

### 失败、停止与限制

- 默认沙箱中网络/uv 缓存不可用；改为工作区缓存并通过工具的授权升级安装项目所需依赖。
- Git 子模块命令开始时缺少 Git Unix 工具 PATH，补齐 Git 的 `usr/bin` 等目录后初始化成功。
- PyMTL Windows 显式文件名重复 rename 报错；采用显式 module name、工作目录隔离的翻译方法。
- `pytest tile/test/TileRTL_test.py` 的批量基线运行在首个通过后长时间无结果（约 603 CPU s），主动停止；不计作通过。后续有针对性地排查和执行。
- 探索性映射前整体 flatten 使用约 7.6 GB 内存且长时间未结束，主动停止；没有有效 PPA 数据。
- 层次网表最终 `check` 未先加载 Liberty 黑盒，产生大量标准单元相关告警；阶段 A 必须区分这些假警告与真实未驱动信号。
- 用户要求先出计划后，停止所有运行中试验。完整网表时序当时停在 flattened JSON 输出阶段，该中间文件可能不完整，不作为结果或缓存使用。

## E01：按已确认计划开始，阶段 A

2026-09-17 17:28–17:30：

- 创建 `codex/noc-4x4-opt`，准备基线/工具独立提交。
- 主智能体建立本日志，更新计划状态；忽略事先已有的库目录，单独记录获取来源与 SHA256。
- 将基线诊断数据整理为可跟踪的精简结果，工具、大网表与临时日志保持忽略。
- 复用三个子智能体：分别处理全网表时序与告警、只读审核与 Mux 设计、CGRA 差分验证。
- 阶段 A 完成后才能提交正式基线口径；RTL 候选在下一笔独立提交中记录。

后续条目将记录每项实验的动机、文件、命令、证据、结论和 Git 对应关系。

### A 阶段复核与口径修正（17:30–17:36）

- `/root/area_report` 独立核对实例参数、源文件和库 hash、面积总和，未发现参数偏离或漏计；35-bit DataType 含 32-bit payload，额外 NahRTL 是原 FU 自行补入。
- 主智能体将综合末尾检查改为先 `read_liberty -lib -nooverwrite`，再 `check -mapped -assert`；修正层次 summary 的时序描述，避免将分模块延迟误称全设计延迟。
- 基线同一映射网表补检：加载库后 `Found and reported 0 problems`。日志 `build/baseline/hierarchical/timing_diagnostics/check.log`，该步骤没有重映射或修改网表。
- 新增 `collect_results.py`，将面积、参数、原始 artifact hash 和补检结果归档到 `results/A0-baseline.json`；另保留 CSV/Markdown 面积表。
- `generate.py` 增加禁止覆盖既有 RTL 的检查和源码差异 hash；库、工具、数据参数均不变。
- `/root/noc_contract` 跑现有 Crossbar 两测和 Tile ALU：3 passed / 3.83 s，日志 `build/stage_d_pytest/baseline.log`。
- `--test-verilog` 的 Tile ALU 在调用工具时失败：Windows shell 找不到 `verilator` 无扩展名入口；套件有 Perl 入口和 `verilator_bin.exe`，本地 PyMTL 导入构建未通过。两个旧 Crossbar tests 被插件 skip，不能声称它们完成了该项检查。
- `/root/synth_tools` 的流式逻辑展平在小网表复现原方法的 418.62 ps；完整基线发现 205 个 x 顶层输出，恰为 `is_multi_cgra=False` 时未连接的 inter-CGRA 包接口（rdy 1 + val 1 + msg 203）。这些是该固定实例未启用的端点，不应赋 0 伪造时序。要求对精确端口显式记录排除原因，并进一步检查任何 x 是否进入实际逻辑。四边 Tile 数据端口必须全部保留。
- 第一笔提交冻结已复核的面积流程、验证基础设施与基线摘要；完整时序脚本和 CGRA 差分脚本仍在各自子任务验证中，待稳定后独立纳入版本。

### A 阶段时序诊断结论（17:42–17:46）

- 首笔 Git 提交：`14ce5bc`，仅基线、工具与记录，无 RTL 改动。
- `/root/synth_tools` 完成流式层次别名展开，逐个覆盖 2,063,725 个标准单元：1,914,356 组合门和 149,369 DFF，2711 个模块实例，一个正沿时钟域。避免了 1.5 GB 以上 flattened JSON 的中间表示。
- 排除显式核实为全 x 的 205 个未启用端口位后，仍有 **8800 个组合门输入为 x**：VectorMulRTL 4800、VectorAdderRTL 2752、FlexibleFuRTL 1232、ConstQueueDynamicRTL 16。没有 x FF 输入，没有另外的无驱动整数网。早期把常量 x 编号 2 计作未驱动网的诊断 bug 已修正。
- 例证包括 Tile 未连接的 ConstQueue.clear、VectorCombo 未赋的部分输入/消息字段。未修改这些 FU/常量队列问题，未将 x 绑 0 或当作新增外部输入。
- 因此本实验的整机 delay 和 frequency reference 均明确记为 **null/unavailable**。面积仍按统一映射流程记录；不以分模块 ABC 延迟代替整机数据。
- 归档：`results/A0-timing-diagnostics.json`；完整 pin 清单与命令日志在 `build/baseline/hierarchical/timing/`。主智能体复核了端口例外必须匹配 manifest、所有有效消费者严格检查、失败不进入 ABC 计时的逻辑。
- 阶段 A 的测量口径至此固定。后续候选使用相同库、综合脚本、层次展开和诊断规则。
- 第二笔 Git 提交：`74eb4fc`，冻结完整时序覆盖诊断、基线限制与复现说明；仍无 RTL 修改。

## E02：控制环固定索引 Switch，阶段 B

17:37 起，由 `/root/area_report` 实现，主智能体复核及集成：

- 新增 `noc/StaticSwitchUnitRTL.py`，替换消息选择方式；保留 RoundRobinArbiterEn、Encoder、`en=1`、idle input0 消息、背压下仲裁推进和原 readiness 公式。
- `cgra/CgraRTL.py` 通过 RingRouter 既有 `SwitchUnitType` 参数注入全部 51 个 switch；没有修改外部参数、接口或 PyOCN 子模块。
- 新增 `noc/test/StaticSwitchUnitRTL_test.py`，以及独立翻译/等价/局部综合脚本 `sys_lib/verify_switch.py`。
- 首轮测试辅助函数对 Bits 类型错误调用 `from_bits`：5 failed / 1 passed；仅修复测试类型转换后 6 passed / 19.18 s。覆盖 2/3/5/6/8 输入、32-bit 与真实 199-bit 控制包、所有请求位图和背压、无效消息、reset。
- `python sys_lib/verify_switch.py --output sys_lib/build/switch_b01 --case control6x199 --synth`：1948 周期差分通过；Yosys 无输入假设等价证明 500 点、206 输出位与 6 仲裁状态位全部通过（8.70 s）。
- 同一局部完整 switch 分层映射：基线 25,295.004 面积 / 18,484 cells，新实现 2,096.612 / 1,194 cells，局部面积下降 91.7114%。两边 `check -mapped -assert` 均通过。这不是整机节省比例。
- 主智能体已生成 `build/B1-static-switch/` 独立 RTL 快照，完整 CGRA 综合正在运行；该快照保留源文件 hash，后续源码变动不影响本次测量。
- `/root/noc_contract` 同时进行完整 CGRA fresh-process record/replay；`/root/synth_tools` 在阶段 A 完成后独立审查该 RTL。

### B 的完整结果与归因复核

- 完整 CGRA 映射完成，367.61 s；总面积 **2,104,402.342**、**1,206,277 cells**，相对 A0 减少 1,168,390.636（约 35.70%）。加载库后的 `check -mapped -assert` 为 0 个问题。
- 控制环：1,799,792.176 → 632,451.442；controller：102,897.046 → 101,847.144；其余十类的面积及单元数均与 A0 精确相同。
- 为解释 controller 的 1,049.902 差额，`/root/area_report` 对比了两份冻结 RTL。controller 可达的 27 个模块全文完全相同；98 个层次实例中，差异仅在 `controller/crossbar/switch_units__0/mux`，即未改动的 7×204-bit Mux。其面积 16,050.972 → 15,001.070，单元 12,381 → 10,968。ABC 前均为 9585 generic cells、2996 个 undef 替零。确认属于同一 RTL 的映射变化，具体 ABC 排序/启发式触发原因未证明，不能把这一小部分声称为源码优化的直接收益。
- `/root/synth_tools` 对 B 进行独立源码审查，未发现问题。额外 3×32、8×32 Switch 形式验证分别证明 274、371 点，包含全部输出及 3/8 个仲裁状态位。
- 新增 import 专用测试，普通运行通过。首次 `--test-verilog` 因系统临时目录权限失败；改用工作区 `--basetemp` 后 RTLIR 翻译成功，随后仍因 Windows 找不到 `verilator` 入口而无法导入构建。报告不将其记为通过。
- 完整 CGRA INC 差分通过：113 cycles / 226 个时钟沿前后快照，54 个顶层输出端口的全部位（含无效消息）一致；64 次配置/启动握手、16 次完成握手、9 个 CPU 输出背压周期。证据：`build/stage_d_inc_smoke2/verification_report.json`。这是有限集成用例，不是所有程序的整机形式证明。
- `/root/noc_contract` 继续四边数据路由、多播、prologue 的基线录制；`/root/synth_tools` 对 B 的冻结网表运行同口径时序覆盖检查。
- 整机验证脚本首个 `stage_d_inc_smoke` 在提取源码时失败：纯 Verilog 子模块没有 `*.py`，`git archive` 返回 128。增加先检查文件列表、无 Python 时跳过提取并保留子模块 revision 的处理后，`stage_d_inc_smoke2` 完成。失败未进入 RTL 仿真。
- B 的全网表时序检查同样发现 8800 个实际 x 输入，delay/frequency 继续为 unavailable。检查覆盖全部 1,206,277 cells（1,056,908 组合门、149,369 DFF），未减少寄存器；库感知网表检查为 0。精简测量、局部证明及 INC 报告归档到 `results/B1-*.json`。
- `/root/synth_tools` 将 ABC 全局运行编号归一化后，确认 A0 与 B 的 8800 条实际 x 引脚记录逐项完全相同，保留了层次、门编号、类型、pin 和 x 值，没有新增或消失的问题。
- 第三笔 Git 提交：`972145e`，独立保存 B 的控制环实现、测试和测量结果。下一笔报告更新中将该 commit 与生成时保存的 RTL hash 关联；原始生成 manifest 仍保留测量当时 HEAD 和工作区差异，不改写历史。

## E03：Crossbar 候选，阶段 C

- 在 B 完整面积数据产生后，授权 `/root/area_report` 先在 `build/C1-factor/CrossbarRTL.py` 中仅提取每输入的选中条件。生产 `noc/CrossbarRTL.py` 暂不修改；不混入 comparator 前移等第二项变换。
- 主智能体给 `verify_crossbar.py` 增加 `--candidate-source`，允许从指定的真实 Python 文件加载候选，继续以原始 Git 基线作比较。所有快照与生成物位于独立输出目录。
- 候选先经过逐周期差分、RTLIR 翻译、Yosys 等价和局部映射；结果再决定是否接入完整 CGRA。失败和无收益的试验同样保留记录。
- C1 初轮差分通过：routing8x8、fu2x8 各 2836 cycles，irregular3x5 2492 cycles，共 8164 cycles；包括 prologue 0–7、selector 截断别名、无效消息和完整状态。三种形状 RTLIR 翻译成功，形式等价和局部面积运行中。这里 ctrl_size=8，与最终固定实例的 ctrl_size=6 区分记录。
- `/root/synth_tools` 独立审查 C1：原循环多个输出命中时每次都写同一个 `old_counter + 1`，共享 OR 归约不改变每周期加一次的语义；没有增加状态、握手依赖或组合环。未发现可操作问题。
- 复用 `/root/synth_tools` 负责 `build/C2-compare/` 的第二项隔离实验：基于 C1，仅将 prologue 比较前移并选择 1-bit 结果。生产文件继续保持基线，两个原型使用不同目录；主智能体独立管理日志和 Git。
- C1 首轮 ctrl_size=8 的局部映射出现回退：routing 9170.084 → 9346.442、FU 2455.712 → 2591.904；对应局部 ABC 延迟也增加（1111.06 → 1153.43 ps、837.16 → 863.64 ps）。这些局部延迟不是整机频率。要求优先补测实际 ctrl_size=6；如果同样无收益，则不接入生产文件，不花整机综合成本重复确认一个已回退的局部候选。
- 因上述证据调整 C2：改从原始 Crossbar 单独做比较前移，保留原 counter 三重循环。未测的 C1+C2 组合原型只留在忽略目录；不让第二项试验依赖可能回退的第一项。该调整在后续结果产生前作出。

### C1 结论及验证工具修正

- 实际 ctrl_size=6 的结果是混合的：routing 面积 8130.024 → 7839.286、局部延迟 1041.86 → 1114.73 ps；FU 面积 2560.516 → 2564.772、局部延迟 729.68 → 800.17 ps。状态单元面积完全不变。
- C1 暂不采纳进最终实现：两个实例的局部延迟都增加，FU 面积也未改善。保留该候选供后续选择；没有运行 C1 整机综合，不能将局部变化声称为整机面积或频率变化。
- 首轮 routing8x8 形式证明通过 1474 点（192 counter + 8 multicast 状态位）。FU 失败仅涉及四个 sv2v 自动生成的循环变量位：新增 block 改变全局编号，导致同名临时变量实际对应不同循环。真正输出和状态未出现未证位；原始失败仍保留。
- 主智能体修改 `equivalence.py`：仅隐藏 `sv2v_autoblock*.i/.j/.addr` 的自动临时名字，不匹配这些非语义信号；所有输出和原始状态仍必须逐位匹配，新增覆盖审计防止误排除。修正后 FU 通过 590 点、56 状态位及 291 输出位（30.84 s）；irregular3x5 通过 513 点、59 状态位及 184 输出位（20.08 s）。已成功的 routing 网表只补读审计，确认 297 输出位覆盖，不重复运行证明。
- 子智能体归档 `experiments/C1-factor.patch` 和 `results/C1-factor.json`，包括原始失败与修正后的成功证据。patch 首次因 CRLF 检查失败，规范为 LF 后 `git apply --check` 通过，未应用到生产文件。
- 查询 Yosys 帮助时，一次未设置套件运行依赖 PATH 的直接调用未正常返回；中止后，用套件 `bin`/`lib` PATH 调用正常返回。一次只读进程查询被系统拒绝，随后通过原命令会话中止该帮助进程。Yosys 已安装并持续成功执行综合，不是缺少 Yosys。已向用户说明。

### C2 与 C3 的独立筛选

- C1+C2 的早期组合探索在调整指令到达前已开始，最终完成 3672 周期差分与翻译；保存于 `build/C2-compare/`，只视作组合探索。真正单项 C2 使用独立目录 `build/C2-compare-baseline/`，两者 hash 与报告不混用。
- 单项 C2 的 ctrl6 局部面积/延迟改善：routing 8130.024 → 5064.906、1041.86 → 939.25 ps；FU 2560.516 → 1707.720、729.68 → 685.08 ps。仍待目标参数下的差分与形式证明，再决定接入完整 CGRA。
- 主智能体另建 `build/C3-static-demand/CrossbarRTL.py`：从原始 Crossbar 开始，仅将输入需求的动态 bit set 改成 input×output 的固定索引 OR 归约。初次 patch 因注释上下文不匹配未应用，修正精确上下文后成功；没有部分修改生产文件。
- C3 在实际 ctrl6 的 routing/FU 和 irregular3x5 上通过 5364 周期差分，覆盖 prologue 0–7、alias selector 与全部消息/状态，三种形状翻译成功。局部面积评估运行中。
- 主智能体把子智能体已使用的局部映射流程整理为 `local_crossbar_synth.py`，仅增加产物/工具 hash 和禁止覆盖已有报告；综合命令、库与约束保持原流程。它支持复用相同参考实例的已有基线，不把局部数字乘实例数冒充整机结果。
- C3 局部结果：routing 面积 8130.024 → 7745.920、延迟 1041.86 → 1073.32 ps；FU 面积 2560.516 → 2490.292、延迟 729.68 → 783.74 ps。两个局部延迟均增加，默认最终实现不纳入 C3；保留 patch 与 `results/C3-static-demand.json`，没有运行其形式证明或整机综合。
- `/root/area_report` 分别独立审查单项 C2 与 C3，未发现可操作问题。C2 保留原 Bits3 无符号比较、动态索引和旧状态；C3 保留 OR 累积与 alias。ctrl6 的地址 6/7 属原始越界域，不扩张为合法配置。
- 单项 C2 在 ctrl6 两种形状上完成 3272 周期差分及形式证明：routing 1138 点（144+8 状态位）、FU 554 点（36+8 状态位），全部输出位覆盖、无输入假设、0 未证（125.59 s / 14.72 s）。基于已通过的行为检查和局部结果，准备将单项 C2 接入最终版本；C1、C3 继续作为独立候选留档。

## E04：整机逐周期集成验证，阶段 D

- `/root/noc_contract` 的 B 版本全部通过：INC 113 cycles、boundary 184、boundary_prologue 260，共 **557 cycles / 1114 snapshots**。每个时钟沿前后比较 54 个顶层输出端口的全部位，包含无效消息；三种场景关键 RTL hash 完全一致。
- boundary 与 boundary_prologue 各接受 16 个边界输入、产生 32 个边界输出，并收到全部 16 个 COMPLETE；prologue 场景还包含额外 64 条配置。边界反射多播和四方向穿越整个 Mesh 均检查了数据内容与顺序。
- 普通 boundary 中的 35 个 stall 计数是“输出端口×阻塞周期”，同一全局周期多个端口分别计数；不误写为 35 个唯一全局周期。
- 完整录制轨迹保留在 `build/stage_d_boundary_reference/`；B 重播报告归档为 `results/B1-cgra-boundary.json`。新增 `verify_cgra.py` 支持冻结源码、新进程、轨迹 hash、首次差异与已完成基线复用；报告明确有限测试范围。

### C2 接入与最终测量

- 第四笔提交 `0474ab8` 保存整机重播工具、B 的完整验证、C1/C3 独立候选与验证脚本修正。归档 patch 中的空白上下文行被 Git 空白检查提示；这是 unified diff 的必要前缀，后续为 `experiments/*.patch` 单独设置尾空白检查属性，不改 patch 内容与 hash。
- C2 筛选完成：ctrl8 两种形状、ctrl6 两种形状及 irregular3x5 共 **8436 cycles / 16877 snapshots**；ctrl6 两形状和 irregular 三项形式证明共 2205 点、无未证。逐输出与状态覆盖审计全部通过；精简证据为 `results/C2-compare-screening.json`。
- 主智能体按原样将已验证的单项候选复制到 `noc/CrossbarRTL.py`，SHA256 `40f5077b172e2c8f9917eb70012a0119c7df13c996e0314a926ef3d56080b5a4`。没有加入 C1 或 C3，原寄存器、复位、控制编码和接口保持不变。
- 下一步在此明确版本上生成新的完整 CGRA 网表、执行相同综合/时序诊断，并复用完整基线轨迹验证最终 B+C2 集成版本。
- 第五笔提交 `e91686f` 固定单项 C2 与筛选结果。最终整机生成时工作区 diff 为空，manifest 精确记录此完整 commit；生成 RTL 为 1,044,261 bytes，SHA256 `caa087be49e7130099add7b7ce23da646aab3817c5189df4a440bf738236d19c`。
- `/root/area_report` 完成最终限定回归：旧 Crossbar 两测、Tile ALU/prologue、ContextSwitch ALU、StaticSwitch 七测，共 **12 passed / 49.60 s**。现有弃用警告保留日志。Tile prologue 的 `--test-verilog` 已生成 327,588-byte RTL，导入阶段仍受 Windows `verilator` 入口限制而失败；未计作通过。生成文件移入本次 build 目录，未修改 RTL。归档 `results/final-regression.json`。
- `/root/noc_contract` 从原始基线分别并行重播最终 INC 与两个边界场景，快照 hash 核实为 C2；源码与基线轨迹都不随运行中的工作区变化。

### 时序缺失原因的进一步核实

- 等待最终综合时，`/root/synth_tools` 对 A0 做了独立只读路径追踪，核实 x 告警并非全是没有时序终点的死逻辑。
- `tile__0/const_mem.clear=x` 经 OR2_X1、NOR3_X1 两级组合门到达 `consume_pending` 的 DFF.D；结构上还可到达读/写指针，共 7 个局部 FF 输入。另一组输入分别来自 reset 和 ctrl_proceed。完整实例/门名、引脚链及库函数归档于 `results/A0-x-reachability.json`。
- 这是具体结构可达证据；没有声称已检查全部 8800 项的可达性或逻辑可敏化，也没有修改统一时序口径、绑定 x 或重映射。至少存在真实 FF 终点，因此不能简单将所有这些输入作为无关端口排除。

### 最终完整综合及覆盖结果

- C2 完整映射 317.796 s，面积 **2,049,466.692**、**1,160,207 cells**，加载库后的 `check -mapped -assert` 为 0。最终网表 SHA256 `7c058d9ec2357d96e442ac69b581383807ec33b2295d1d6b4bbbf23fa13b1739`。
- `/root/synth_tools` 用冻结的同一时序脚本检查全部网表：1,010,838 个组合单元、149,369 个 DFF，相比 B1 仅组合单元减少 46,070。时钟域、FF 数量和端点数量相同。
- 仍有 8800 个未知组合输入（VectorMul 4800 / VectorAdder 2752 / FlexibleFu 1232 / ConstQueue 16）。FF 直接输入 x=0、真实未驱动整数网络=0，三项停用端口共 205 bits；组合门上的 x 可经逻辑影响 FF，不能用“FF 直接输入 x=0”否认该问题。
- 对 A0/B1/C2 仅归一化 ABC 运行编号后，8800 条逐引脚记录完全相同，双向集合差均为 0；delay/frequency 均保持 null。未改变 flow、库、驱动或负载。
- 最终完整测量归档 `results/C2-final.json`、`results/C2-final-area.csv/.md`，时序归档 `results/C2-timing-diagnostics.json`。生成 provenance 对应完整 commit `e91686f7b6133f615bec76eb5bba6edbda1e5f1c`。
- `/root/area_report` 独立遍历最终 write_json 中全部叶单元并查 Liberty，得到同样的 2,049,466.692 面积和 1,160,207 单元，与 Yosys stat、12 类归属及另一套父层级分组总和精确一致。三个 manifest 参数相同，源 RTL 与记录 hash 匹配，库实际 hash 一致，Yosys/sv2v 二进制 hash 与历史证明记录一致。
- C2 相对 B 的 controller 面积 +634.942，精确分为同一 7×204 Mux 的 +628.292，以及 `global_reduce_unit/queue/ctrl` 的 +6.650（75 单元数不变、门型/尺寸变化）。可达的 27 个转换后模块文本完全相同。均属于映射变化，具体 ABC 内部启发式原因未证明。
- 归档 `results/controller-mapping-audit.json`。原始综合 summary 未逐次记录 ABC 可执行文件 hash，因此报告只记录当前配套 ABC hash 与已有版本信息，不补造历史 hash。

## Git 与产物索引

工作分支：`codex/noc-4x4-opt`。功能版本及过程按下表拆分；最终收尾提交只归档数据和文档。

| 提交 | 内容 |
|---|---|
| `41cb0c0` | 原始 RTL 基线 |
| `14ce5bc` | 基线面积流程、参数、验证基础设施与实验日志 |
| `74eb4fc` | 全网表时序覆盖诊断与基线限制；可复现 A0 的工具版本 |
| `972145e` | B 控制环静态选择及对应局部/整机结果 |
| `0474ab8` | 整机重播、B 全部周期验证、C1/C3 筛选与验证脚本修正 |
| `e91686f` | 单项 C2 比较共享；最终 B+C2 RTL 与局部证明 |

查看全部更新：`git log --oneline 41cb0c0..HEAD`；只看功能改动：`git diff 41cb0c0 e91686f -- cgra/CgraRTL.py noc/CrossbarRTL.py noc/StaticSwitchUnitRTL.py`。最终数据归档版本可由本日志的 Git 历史定位，测量对应的 RTL 版本始终明确为 `e91686f`。

- 统一复现入口：`README.md`；原始约束与阶段：`OPTIMIZATION_PLAN.md`。
- 完整面积数据：`results/A0-baseline.json`、`B1-static-switch.json`、`C2-final.json` 及各自 CSV/Markdown。
- 证明与差分：`results/B1-switch-*.json`、`C2-compare-screening.json`、`B1-cgra-*.json`、`C2-cgra-*.json`、`final-regression.json`。
- 未默认采纳的实验：`experiments/C1-factor.patch`、`C3-static-demand.patch` 及同名结果 JSON。
- 时序限制与归因：三个 `*-timing-diagnostics.json`、`A0-x-reachability.json`、`controller-mapping-audit.json`。
- 原始日志、压缩轨迹和网表保留在 `build/`；本地工具、Python 环境、工艺库按既定规则忽略，没有删除本轮证据或改动用户原有库。

## E05：收尾

- `/root/noc_contract` 完成最终 B+C2 的全部重播：INC 113 cycles / 226 snapshots；四边通信与 prologue 444 cycles / 888 snapshots。合计 **557 / 1114**，54 个顶层输出在每个时钟沿前后全部位一致，包含无效消息；轨迹 hash 与各自原始基线一致。
- `results/C2-cgra-inc.json` 与 `C2-cgra-boundary.json` 记录完整 `e91686f…` 版本。归档前再次核对三个关键 RTL 快照的 hash 与该提交的 Git blob 完全一致，原始基线与轨迹未改写。
- 全部子智能体作业已结束。主智能体复核结果与日志、更新计划状态和复现说明，将最终数据作为报告提交保存；没有推送、创建 PR 或合并。
- 一次只读 Git 状态查询尝试使用 Windows `NUL` 作为临时 exclude 文件，被 Git 拒绝；改用仓库普通 exclude 文件继续查询。没有修改 Git 全局配置，该错误与综合/仿真无关。
- 后续决策所需数据和未解决限制已经完整保留。若要确认原始双目标中的频率提升，仍需先明确处理基线未定义信号，再按统一条件重新测量基线和候选；本轮未擅自改变这些 FU/队列语义。

## E06：继续补齐频率比较（2026-09-18）

- 用户在解释频率缺失原因后，明确要求尝试统计修改前后的频率。本阶段从干净的 `b8697ce` 开始，复用原分支与实验日志；A0 和 C2 的冻结映射网表、源 RTL 与历史面积不覆盖。
- 更正测量限制的表述：旧流程是自定义 `mapped_timing.py` 在发现 x 引脚后主动终止，尚未调用整机 ABC `stime`。这不等于“存在 x 就无法进行任何静态时序分析”，也不是 Verilator 导入失败或缺少 Yosys。
- 继续复用三个子智能体：`synth_tools` 在 `build/timing-method-v2/` 隔离探索保留全部映射单元的结构时序方法；`noc_contract` 只读审核向量 FU/常量队列未定义字段的来源、消费者和三类 Tile 的 clear 语义；`area_report` 独立审核时序端点、驱动/负载、虚拟输入和潜在组合环的处理。主智能体负责选择测量口径、复核证据、Git 和统一日志。
- 优先区分真实外部输入/FF 发起的路径与未定义侧输入的诊断路径，不偷偷将 x 绑零、删除路径或用局部延迟替代整机结果。若确需补连 RTL，则必须说明语义依据、对基线与候选共同应用，并重新综合统计面积。

### 测量方法探索与审查

- `noc_contract` 找到的主要 X 来源包括 VectorAdder 进位临时量高位、子操作数高位、两个 Combo 的闲置 ready 和普通/Streaming Tile 的常量队列 clear；ContextSwitch 已有真实 clear 连接。五个文件的最小补连原型只存于 `build/x-source-audit/`，只做了 AST 检查，未应用到生产，也未声称与原始四态 RTL 等价。
- `synth_tools` 为 8800 个 X 输入引脚分别建立独立、显式的虚拟发起点；没有将它们绑零，也没有把全部 X 合成一个虚假高扇出网络。保留所有映射门后用 Kahn 排序检查，C2 的 1,010,838 个真实组合门和 2 个常量伪门全部排序成功，无组合环。
- 首次 ABC `topo; stime` 虽能输出数值，却删除了 C2 的 24,027 个悬空门，因此该数值没有作为最终结果。外部排序保全门后，stock ABC 的检查又因无 fanout 门拒绝执行；这与真正的组合环不同。
- `area_report` 用小探针确认 stock ABC `stime` 忽略 BLIF input_arrival；`read_constr -n` 的参数实现也没有启用新的约束管理器。仅修命令开关仍不足以让计时内核读取逐输入到达时间。没有编译或修改 ABC。
- 主智能体提出并实现仅分析用的路径标记模型：对每个发起点显式放置 BUF_X1 模型，对每个真实终点放置输入电容恰为 5 fF 的标记；目标发起类和终点类分别加固定时间 K，最后减去 2K。原真实门、引脚和负载保留，BUF 和终点标记不属于物理设计，不计入面积。悬空门输出添加诊断终点，只影响没有下游逻辑的输出，不改变原门对上游的输入电容。
- 本次统一改为绝对 BUF_X1 延迟模型；旧 ABC global driver 采用 `delay(load)-delay(0)`，故不与旧局部延迟混用。两版用同一模型重新测量。小探针在 K=100/200 ns 时 FF→FF 均为 64.19 ps，PI→FF 均为 45.19 ps；类别和门数正确，独立审查确认物理门的 slew/load 不随选择类别变化。
- 脚本强制核查 ABC 回读的全部门类型计数、stime 门数和获胜路径的发起/终点索引；dummy/闲置发起点的诊断终点不能作为有效结果。ABC 加 `-s` 固定启动条件。第一次完整探针因 cutpoints 中的字段名为 outputs 而脚本预期 endpoints 失败，修正兼容读取后重试，没有修改或覆盖原网表。
- `synth_tools` 同时实现独立的 Liberty NLDM 分类传播器，用于与 stock ABC 结果交叉校验；它的单独结果不冒充 Yosys/ABC 输出。

### 完整测量、验证与归档

- stock ABC 的 A0 FF→FF 延迟为 **5944.83 ps / 168.2133888 MHz**，C2 为 **5864.88 ps / 170.5064724 MHz**；延迟下降 1.344866%，倒数频率提升 **1.363199%**。两版使用同一 K=100 ns 标记库和 5 fF 终点，原始物理单元、源网表和面积完全不变。
- 改用 K=200 ns 后 A0 为 5944.91 ps、C2 为 5865.00 ps，最大差异 0.12 ps，远小于版本间约 79.95 ps 的变化。没有仅凭一次偏置得出结论。所有获胜起点为真实 FF.Q、终点为 FF.D；完整回读单元类型/计数审计均通过。
- ABC 两次 FF→FF 测量都保留 A0 的 1,914,356 / C2 的 1,010,838 个原始组合单元及各 2 个常量伪门。另有各 308,554 个测量源和 150,130 个测量终点，所以 ABC 计时模型总节点分别为 2,373,042 / 1,469,524；这些额外标记不是硬件，也不计入面积。每版原有 149,369 个 DFF 均被逐引脚切开分析。
- `synth_tools` 的独立全图 NLDM 给出 A0 **5944.841608 ps**、C2 **5864.907587 ps**，与 stock ABC K=100 ns 相差 0.011608 / 0.027587 ps。五项小网表验证全部通过，最大数值差小于 0.005 ps。早期剪枝图的独立 all-source 12844.623677 ps 也与 ABC 12844.63 ps 相差 0.006324 ps；该剪枝图仅作计时器验证，不作为整机测量。
- 全图全部来源的 stock ABC 延迟为 A0 13131.25 ps、C2 13052.45 ps，获胜起点都是 reset，终点都是 Tile 8 的寄存器输入。独立全图值分别为 13131.691895 / 13052.897311 ps，相差不足 0.45 ps；这种复位/边界路径倒数没有被当作时钟频率。独立诊断保留 PI/FF/虚拟 X 到 FF/PO 的全部六类数据，虚拟输入类别没有被省略。
- 数字仅报告约 0.1 MHz 精度。原库的条件弧合并、ABC 的 float32 运算与超表外推均保留，独立引擎采用 float64；尤其大复位负载下，不应把输出的全部小数位视为精确值。
- `noc_contract` 逐门归属核实：关键结构路径从 Tile 0 控制存储器经其寄存器/路由/访存地址，经过共享内存请求仲裁与响应路由，到 Tile 8 的 FU ready、ctrl_proceed 和寄存器写译码。代表性独立路径 129 门中，Tile 0 为 36 门、共享内存为 47 门、Tile 8 为 46 门；没有经过 Tile mesh Channel、LinkOr、控制环或内存读数据阵列。代表性并列终点为 bank 3，ABC 为 bank 0，报告明确区分。
- 同一代表路径经过 Tile 8 中互斥 opcode 下的 MemUnit/Adder 分支，属于功能假路径候选。没有证明可敏化，也没有临时增加 false-path 约束以缩短结果。这是组合结构估计，不是签核 Fmax；原始 X 信号的语义尚待独立修复，本阶段没有修改 FU/Tile。
- `area_report` 将虚拟输入导出和 Kahn 排序整理为 `structural_cutpoints.py`。包含独立 X、重复终点、悬空门、环拒绝和非空输出拒绝的微型验证通过；真实 C2 再导出一次，full.blif、full.gates、coverage.json、cutpoints.json、all_ordered.blif 五项与探索版本逐字节 SHA 相同。没有重新综合或重复整机计时。
- 主智能体将分析整理为 `abc_path_groups.py`，保留未修改的严格 `mapped_timing.py`。`synth_tools` 整理 `class_nldm.py` / `validate_nldm.py`，核心算法区块 hash 与已验证版本相同，仅调整默认路径、CLI 和报告元数据。安装位置的单门独立计算和分组 ABC 小探针再次通过。
- 归档 `results/frequency-comparison.json`、两份 `*-frequency-independent.json` 与 `frequency-path-attribution.json`；新增 `TIMING_COMPARISON.md` 说明数字、条件、限制和复现入口，并更新 README。一次归档脚本因 package manifest 路径漏写 package 子目录失败，修正后成功；没有影响原始运行结果。
- 本阶段复用原来的三个子智能体，没有创建新的用户任务，没有应用隔离的 X 补连原型。最终只提交分析工具、结果和文档，原 NoC 硬件版本仍为 `e91686f`；已有整机面积下降 **37.378664%** 的结果保留。
- `noc_contract` 最终只读审查未发现 P1/P2：五个脚本 SHA、六次 ABC 数值与原始报告 hash、全门覆盖和模型限制一致，生产路径 Git diff 为空。采纳其非阻塞建议，在主表注明统一 BUF_X1 驱动模型。主智能体通过 Python 编译检查与 Git 空白检查；本阶段没有 RTL 改动，因此没有重复运行已完成的 RTL 仿真/形式证明。
- 暂存检查发现新脚本末尾多一个空行，以及 Windows 产物的 CRLF 与仓库 LF 规范不同。归档脚本统一新工具/JSON 的 LF 和文件末尾，重新记录实际归档 SHA；`build/` 原始运行文件及其原始 hash 保持不变。数学算法与测量数值未变。

## E07：SystemVerilog 迁移方案评估（2026-09-21，未开始迁移）

- 用户要求结合附件评估原生 SystemVerilog 迁移的可行性、难点及待澄清事项，并明确选择附件 `master@ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b` 为基线。本次仅评估，不执行附件中的迁移命令。
- 复用 `/root/area_report`（基线及资产）、`/root/noc_contract`（行为合同）、`/root/synth_tools`（工具、验证及 IP）三个子智能体；没有新建用户任务。全部子任务均限定只读核查。
- ac96 历史提交实际已在本机 Git 中，缺少的是附件未提交的 G00 封装/脚本/测试及原始生成产物。当前优化实例与附件 G00 的 FU 组合、控制深度、主机包宽度不同，原优化的周期、面积和频率证据不能直接移用。
- 核查发现应具体规定无效消息位的比较范围、反压期间仲裁行为、旧操作码冲突/常量推进缺陷、X 信号处理，以及工具内部 Python 的允许边界。未将这些发现直接修入 RTL。
- 新增 `docs/SYSTEMVERILOG_MIGRATION_ASSESSMENT_2026-09-21.md`，记录可行性、证据、计划修正、待确认项及子智能体分工。仅新增评估文档和本日志记录；未切换分支、创建迁移工程、运行仿真/综合、提交或推送。
- 用户随后选择“日常工具环境完全无 Python”，并询问日常 Verilog 开发是否需要 Python。报告据此更新为严格环境约束，同时解释硬件源码、项目脚本和工具内部辅助脚本的区别；未将解释视为用户撤销严格要求。
- 用户了解区别后明确更正：允许工具内部调用 Python。已同步修订评估报告，以“项目 RTL、测试和配置流程不依赖 Python/PyMTL，允许 EDA 工具内部 Python”为当前要求；不再将 Verilator 辅助脚本视为迁移障碍或要求环境移除 Python。本次仅修订文档，未创建子智能体或执行迁移。

## E08：迁移实施转入独立分支，2×2 第一阶段完成

- 用户授权开始迁移，将第一阶段指定为单 CGRA、2×2 Tiles。以 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b` 创建 `codex/sv-migration`，独立工作树 `D:/work/VectorCGRA/.worktrees/VectorCGRA`。本 NoC 分支的硬件保持原版本；这里只补充文档索引。
- 新计划分五阶段：固定 2×2 独立运行、参数化单 CGRA、向量/浮点与 Tile 变体、多 CGRA/系统扩展、全项目替代。第一阶段使用冻结 HDL 核心及原生 SV 顶层/类型/测试，不声称通用参数化或全项目迁移完成。
- 新分支提交：`02b838c` 计划与日志，`7a1608d` 参考资产与固定 HDL 核心，`ff09971` 原生运行入口、验证、独立构建和结果归档。
- 两轮四 Tile 运算结果为 28 与 −11；主机配置、跨 Tile 通信、跨 bank 访存、复位重配和反压通过。134 周期 × 489 位活动输出对照冻结 HDL，且 505 位输入/489 位输出重播原 Python 记录全部一致。类型、错误预期和 200 周期超时负测通过；独立目录不含项目 Python，重新编译和综合通过。
- Nangate45 映射最终检查为 0 problems，标准单元面积 773,152.408、叶单元数 474,566。独立审查纠正了误减一个层次实例造成的单元计数错误，原始网表及面积未改；本阶段没有频率测量。
- 继续复用 area_report、noc_contract、synth_tools 三个子智能体。完整过程、工具失败与修正、源码/日志哈希和覆盖限制见新工作树 `sv/EXPERIMENT_LOG.md`、`sv/results/`；26 份关键证据已压缩归档。没有推送或合并 master。
