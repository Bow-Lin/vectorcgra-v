# 4×4 VectorCGRA NoC 优化实验记录

本文件是实验全过程的统一记录。方案见 `OPTIMIZATION_PLAN.md`；精简测量数据放在 `results/`，原始大文件和工具日志留在忽略的 `build/`、`tools/` 中。未运行、失败、停止与通过分别记录。

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
| `/root/area_report` | 面积分解脚本和热点定位 | 独立审核基线与脚本；后续负责受控 Mux 候选实现 | 当前只读审核；实现时另行明确文件范围 |
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
