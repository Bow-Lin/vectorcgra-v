# VectorCGRA SystemVerilog 工程

第一阶段目标是单个 CGRA、2×2 Tiles 的独立运行。后续阶段见 [MIGRATION_PLAN.md](MIGRATION_PLAN.md)，实施记录见 [EXPERIMENT_LOG.md](EXPERIMENT_LOG.md)。

## 当前实现

- 顶层：`cgra_2x2`，源码 `rtl/cgra/cgra_2x2.sv`。
- 核心：`rtl/fixed/cgra_2x2_core.sv`，来自 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b` 的固定展开 RTL。106 个模块、13 个结构体仅重命名以隔离命名空间，没有修改组合逻辑、状态机、接口或寄存器边界。
- 公共类型和编码：`rtl/common/cgra_types_pkg.sv`，用于原生 SV 配置开发。
- 测试：独立 SV 测试平台及已归档的配置、参照数据。正常仿真和综合直接编译 HDL，不运行 PyMTL 或项目 Python 生成器；允许 EDA 工具内部使用 Python。

这是固定实例的第一阶段工程。所有核心源码已经以 HDL 形式保存，可直接阅读和修改；尚未逐模块手工整理、恢复通用参数化。请勿将其等同于全项目迁移完成。`reference/` 是冻结参照；后续开发修改 `rtl/`，不要同步修改参照以掩盖差异。

## 固定配置与端口

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

## 第一阶段运行用例

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
| `tb/` | 原生 SV 测试与独立配置构造 |
| `vectors/` | 已归档的配置包、类型黄金样本和 Python 参考轨迹 |
| `reference/` | 固定参考 RTL、来源及重命名校验 manifest |
| `scripts/`、`filelists/` | 正常编译、仿真、综合入口 |
| `migration_tools/` | 迁移取证脚本，正常构建不调用 |
| `build/` | 中间产物和完整日志，不入 Git |

## 运行

本机从迁移工作树根目录执行：

```powershell
& ./sv/scripts/run.ps1 -Task all `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

这会运行类型编码检查、两轮系统仿真、错误预期负测、永久反压超时负测及 Yosys 通用综合检查。工具路径只表示本机安装位置，不依赖该路径下的 Python 项目。`-Task sim` 只运行系统仿真；`-Task probe` 验证工具语言支持。

若需标准单元面积，在同一命令中使用 `-Task synth-mapped`，并增加：

```powershell
-Liberty D:/work/VectorCGRA/sys_lib/lib/NangateOpenCellLibrary_typical.lib
```

Windows 已验证组合为 MSYS2 Verilator 5.050、Clang++ 22.1.8、GNU Make 4.4.1、sv2v 0.0.13、Yosys 0.69+62。Unix 入口为 `make -C sv all`，本轮未在 Unix 实测。更详细的参数和本机编译适配见 [scripts/README.md](scripts/README.md)。

## 已完成的验证

| 检查 | 结果 |
|---|---|
| 公共类型 | 5 个位宽和 4 个独立 PyMTL 黄金打包样本通过 |
| 两轮系统运算 | 28 与 −11；复位重新配置后结果正确 |
| 四 Tile 与访存 | 每轮 4 完成包、4 条相邻传输、2 次主机回读、1 次外部多播 |
| HDL 对照 | 134 个采样周期 × 489 位活动接口输出，包含无效周期消息，全部一致 |
| Python 参考重播 | 同样 134 周期，505 位输入及 489 位输出全部匹配 |
| 失败测试 | 错误预期触发失败；永久 West 反压在第 200 周期超时；均验证非零退出 |
| Yosys 综合 | 层级检查、通用网表检查及标准单元映射后检查通过 |

Nangate45 typical 条件下，当前固定设计的标准单元总面积为 **773,152.408 µm²**，标准单元数 **474,566**，其中 DFF_X1 为 **49,228**。该计数已按映射网表递归到标准单元叶节点独立核验，不包含层次实例。本阶段没有测量最高频率，也不与此前不同配置的 4×4 优化结果比较。

本轮是所选 Verilator 二态语义下的有限程序验证，不是四态 X 语义或所有合法程序的证明。源 RTL 的位宽、组合依赖和未驱动警告保留在日志中，脚本没有用 `setundef` 或补零改写硬件。完整日志在 `build/`，可追溯摘要在 `results/`；26 份关键日志与统计已保存到 `results/phase1-evidence.zip`，逐文件哈希见 `results/evidence-manifest.json`，后续重跑不会覆盖该归档。

已将运行所需目录复制到 `build/standalone-phase1`，不包含原 Python 源码、`migration_tools/` 或预编译产物；该目录从头运行 `all` 通过，含类型、系统仿真、两项失败测试及通用综合。运行文件哈希与主工程一致，目录内 Python 文件数为 0。结果和日志哈希见 `results/standalone-summary.json`。EDA 工具内部 Python 仍按用户要求允许。

许可证与来源声明随 `LICENSE` 和 `licenses/` 保留。
