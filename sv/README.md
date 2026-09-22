# VectorCGRA SystemVerilog 工程

当前已完成第四阶段：多 CGRA Mesh/Ring、异构结构、跨 CGRA 任务迁移，以及 DMA/im2col。第二、三阶段的单 CGRA 和 FU/Tile 入口继续保留。第四阶段交付分支为 `codex/sv-migration-phase4`；第五阶段等待用户指令，不在本分支交付范围内。

阶段结果见 [PHASE4_REPORT.md](PHASE4_REPORT.md)，计划见 [MIGRATION_PLAN.md](MIGRATION_PLAN.md)，完整过程见 [EXPERIMENT_LOG.md](EXPERIMENT_LOG.md)。

## 当前实现

- 参数化顶层：[`cgra_scalar`](rtl/cgra/cgra_scalar.sv)，通过 `COLS`、`ROWS`、`DATA_W`、存储深度等参数构造硬件；Tile、bank 和控制环由 SV 的 generate 生成。
- 可配置顶层：[`cgra_programmable`](rtl/cgra/cgra_programmable.sv)，通过 `FU_COUNT`、`FU_KINDS` 选择 FU 列表，通过 `TILE_VARIANT` 选择 Base/Context/Streaming Tile；DUT 文件列表为 `filelists/phase3.f`。
- 兼容入口：`cgra_2x2`，端口不变，内部调用 `cgra_scalar` 的默认 2×2 配置。
- 直接维护的模块按 `rtl/common/`、`fu/`、`mem/`、`noc/`、`tile/`、`controller/`、`cgra/` 分类。正常 DUT 文件列表不再包含 `rtl/fixed/cgra_2x2_core.sv`；该文件只保留作第一阶段历史和组件测试参照。
- 参数类型规则：`rtl/common/cgra_profile_defs.svh` 与 `cgra_profile.svh`；旧 `cgra_types_pkg.sv` 继续保存 2×2 的公共编码兼容接口。
- 测试：独立 SV 测试平台及已归档的配置、参照数据。正常仿真和综合直接编译 HDL，不运行 PyMTL 或项目 Python 生成器；允许 EDA 工具内部使用 Python。

当前范围包括单/多 CGRA；包含标量、向量、归约、组合、定点 MAC、浮点和流式访存 FU，及原架构的 Context/Streaming Tile。`reference/` 是冻结参照；后续开发修改 `rtl/`，不要同步修改参照以掩盖差异。原 FP 格式及向量乘法的 Python/HDL 差异保留并单独登记，使用前请查第三阶段报告的兼容边界。

第二阶段参数点、实际验证结果及合法范围见 [PHASE2_REPORT.md](PHASE2_REPORT.md)。3×2 用于验证原 `CgraRTL(width, height)` 已有的非方形支持；未修改 Python 架构以增加该能力。

## 第四阶段系统入口

- [`cgra_system`](rtl/cgra/cgra_system.sv)：单 CGRA 系统，支持外部 NoC、4/8 端口 Tile、独立读写存储口和可选外设。
- [`cgra_multi`](rtl/cgra/cgra_multi.sv)：同构多 CGRA Mesh/Ring；已验证四 CGRA、共 16 或 64 Tiles。
- [`cgra_multi_template`](rtl/cgra/cgra_multi_template.sv)：不同大小 CGRA、逐 Tile FU 列表和静态定向链路；已验证 21 Tiles 的异构配置。
- [`rtl/peripheral/`](rtl/peripheral/)：DMA、im2col 引擎及 CGRA 集成封装。DMA 默认保留原翻译 HDL 的已知切片行为，详情见第四阶段报告。

`filelists/native.f` 包含本阶段 94 个 DUT 文件。所有新增测试位于 [tests/phase4/](tests/phase4/README.md)，不会调用第五阶段配置工具或旧模块补漏代码。

```powershell
& ./sv/scripts/run.ps1 -Task phase4 `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

可单独选择 `phase4-noc`、`phase4-system`、`phase4-template`、`phase4-migration`、`phase4-peripheral` 或 `phase4-memory`。系统综合另运行 `tests/phase4/system/check_synthesis.ps1`。`regression` 只包括阶段 1–4；整组测试耗时较长。

第四阶段没有测量标准单元面积或最高频率，通用综合的零结构问题不等于原设计没有未定义值。第五阶段的配置工具、独立交付整理及遗留功能补齐已暂存到 `codex/sv-phase5-draft`，等待后续指令。

## 默认 2×2 配置与端口

| 配置 | 数值 |
|---|---|
| CGRA / Tiles | 一个 CGRA，2×2 四邻接 mesh，四个 Tile |
| 每 Tile FU 顺序 | Adder、Mul、Mem、Nah |
| 数据 payload / 完整数据字 | 32 / 35 位 |
| 控制字 / 主机包 | 119 / 191 位 |
| 控制存储 / 每寄存器 bank | 8 条 / 16 项 |
| 数据存储 | 2 bank × 16 字，本地地址 0..31，全局地址字段 7 位 |
| 存储访问 | 沿用 ac96 的组合访问模式 |
| 控制互连 | 四个 Tile 加 Controller，共五节点控制环 |
| 其他 | 无 DMA/im2col；不包含较新版本的 B/C2 NoC 优化 |

顶层保留原 CgraRTL 的端口名称和数组顺序。`cgra_id` 应接 0，`address_lower/upper` 应接 0/31；测试平台通过这些原有输入设置本地身份和地址范围。每个边界含两个 val/rdy/msg 通道。Tile 0/1 位于南侧，Tile 2/3 位于北侧，西到东的列编号为 0/1。

`recv_from_cpu_pkt__*` 用于配置、常量、launch 和主机访存；`send_to_cpu_pkt__*` 返回完成及读响应。数据字的 payload 为 `[34:3]`，predicate 为 bit 2，bypass 为 bit 1，delay 为 bit 0。控制字段和包字段的完整位号见 `reference/manifest.json`。

单 CGRA 配置使用内部 NoC 回环。原接口中 `recv_from_inter_cgra_noc__rdy`、`send_to_inter_cgra_noc__val/msg` 未被基线驱动，不能据这些端口观察系统状态。它们仍保留在顶层；测试只对此三个输出作固定排除，不按 val 屏蔽其他输出消息。

## 兼容 2×2 运行用例

测试通过 CPU 接口写配置和数据，执行以下程序：

1. Tile 0 从 bank 0 的地址 15 读取输入并发向东侧 Tile 1。
2. Tile 1 加 5，向北发给 Tile 3。
3. Tile 3 乘 3，向西发给 Tile 2。
4. Tile 2 加 −8，向南发回 Tile 0，同时向西边界多播。
5. Tile 0 写入 bank 1 的地址 16；CPU 收齐四个完成包后回读 16 和 15。

两轮分别为输入 7、预期 28；复位并重新配置后输入 −6、预期 −11。CPU 和西边界接收端施加反压，检查多播不丢失、不重复，并确认原输入未被修改。独立数学结果检查与原始 HDL 逐周期对照同时执行。更广的 FU 操作、输入边界流量及其他程序属于后续覆盖扩展，不能由这两轮推定全部通过。

## 目录

| 目录 | 用途 |
|---|---|
| `rtl/` | 直接维护和编译的 HDL |
| [`tests/`](tests/README.md) | 原生 SV 测试与独立配置构造；后续测试用例放在此处 |
| `vectors/` | 已归档的配置包、类型黄金样本和 Python 参考轨迹 |
| `reference/` | 固定参考 RTL、来源及重命名校验 manifest |
| `scripts/`、`filelists/` | 正常编译、仿真、综合入口 |
| `migration_tools/` | 迁移取证脚本，正常构建不调用 |
| `build/` | 中间产物和完整日志，不入 Git |

`tests/` 中，`tb_cgra_2x2_scalar.sv` 是原 2×2 系统自检，`phase2_tb_cgra_scalar.sv` 是参数化全阵列自检，另有类型编码、Tile/FU、寄存器、交叉开关及控制环测试。输入向量仍放在 `vectors/`，工具安装自检放在 `scripts/probes/`。

## 运行

本机从迁移工作树根目录执行：

```powershell
& ./sv/scripts/run.ps1 -Task all `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

这会运行类型编码检查、两轮系统仿真、错误预期负测、永久反压超时负测及 Yosys 通用综合检查。工具路径只表示本机安装位置，不依赖该路径下的 Python 项目。`-Task sim` 只运行系统仿真；`-Task probe` 验证工具语言支持。

将 `-Task all` 换成 **`-Task phase2`**，会运行 2×2、3×2、4×4 以及 2×2/64 位/控制深度 16/寄存器深度 8 四个参数点，并检查故意错误和永久反压失败。单独运行 4×4 使用 `-Task phase2-4x4`。每个参数点都经过全部 Tile，独立检查算术与访存结果，并与其自己的 ac96 参考逐周期对照；详细用例见 [tests/phase2_README.md](tests/phase2_README.md)。

使用 **`-Task phase3`** 运行第三阶段全部组件和系统仿真；只运行六种完整 CGRA 用例使用 **`-Task phase3-system`**。完整阵列的通用综合另执行 `sv/tests/phase3/system/check_synthesis.ps1`。第三阶段用例、操作命令和原有行为限制见 [tests/phase3/system/README.md](tests/phase3/system/README.md) 与 [PHASE3_REPORT.md](PHASE3_REPORT.md)。

若需标准单元面积，在同一命令中使用 `-Task synth-mapped`，并增加：

```powershell
-Liberty D:/work/VectorCGRA/sys_lib/lib/NangateOpenCellLibrary_typical.lib
```

Windows 已验证组合为 MSYS2 Verilator 5.050、Clang++ 22.1.8、GNU Make 4.4.1、sv2v 0.0.13、Yosys 0.69+62。Unix 入口为 `make -C sv all`，本轮未在 Unix 实测。更详细的参数和本机编译适配见 [scripts/README.md](scripts/README.md)。

## 第一阶段历史验证

| 检查 | 结果 |
|---|---|
| 公共类型 | 5 个位宽和 4 个独立 PyMTL 黄金打包样本通过 |
| 两轮系统运算 | 28 与 −11；复位重新配置后结果正确 |
| 四 Tile 与访存 | 每轮 4 完成包、4 条相邻传输、2 次主机回读、1 次外部多播 |
| HDL 对照 | 134 个采样周期 × 489 位活动接口输出，包含无效周期消息，全部一致 |
| Python 参考重播 | 同样 134 周期，505 位输入及 489 位输出全部匹配 |
| 失败测试 | 错误预期触发失败；永久 West 反压在第 200 周期超时；均验证非零退出 |
| Yosys 综合 | 层级检查、通用网表检查及标准单元映射后检查通过 |

Nangate45 typical 条件下，第一阶段固定设计的标准单元总面积为 **773,152.408 µm²**，标准单元数 **474,566**，其中 DFF_X1 为 **49,228**。这是 `ff09971` 的历史测量，不作为当前参数化设计的新面积结果。该计数已按映射网表递归到标准单元叶节点独立核验，不包含层次实例。第一阶段没有测量最高频率，也不与此前不同配置的 4×4 优化结果比较。

本轮是所选 Verilator 二态语义下的有限程序验证，不是四态 X 语义或所有合法程序的证明。源 RTL 的位宽、组合依赖和未驱动警告保留在日志中，脚本没有用 `setundef` 或补零改写硬件。完整日志在 `build/`，可追溯摘要在 `results/`；26 份关键日志与统计已保存到 `results/phase1-evidence.zip`，逐文件哈希见 `results/evidence-manifest.json`，后续重跑不会覆盖该归档。

已将运行所需目录复制到 `build/standalone-phase1`，不包含原 Python 源码、`migration_tools/` 或预编译产物；该目录从头运行 `all` 通过，含类型、系统仿真、两项失败测试及通用综合。运行文件哈希与主工程一致，目录内 Python 文件数为 0。结果和日志哈希见 `results/standalone-summary.json`。EDA 工具内部 Python 仍按用户要求允许。

上述第一阶段归档对应提交 `ff09971`，保留当时的 `tb/` 路径；当前测试目录已迁至 `tests/`。目录调整的验证记录见 `EXPERIMENT_LOG.md` 的 M05。

许可证与来源声明随 `LICENSE` 和 `licenses/` 保留。
