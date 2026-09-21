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

运行命令、实际验证结果及工具环境在集成验证完成后补齐。当前状态以实验日志和 Git 提交为准。
