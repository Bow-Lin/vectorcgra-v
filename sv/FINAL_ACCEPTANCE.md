# 本轮迁移最终验收索引

本轮的范围是 [20 项已授权任务](MIGRATION_TASKS.md)：补齐独立接口、修复已确认的语义
问题、整理参数化 PE、验证整机与内核、统一回归并交付独立工程。当前实现和剩余边界见
[CURRENT_MIGRATION.md](CURRENT_MIGRATION.md)，逐文件清单见
[MIGRATION_INVENTORY.md](MIGRATION_INVENTORY.md)。任务完成不代表任意参数的形式等价，
也不代表重写全部 Python 软件。

## 来源与提交

历史起点为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`，固定 Python 目标为
`cd7aad878915e389cecf8cc01ff6987d156bd019`，Python 内容来自其父提交
`e3caf6928a4e8c97e6be36574af2520ec92083b9`。原 274 个 Python 文件按
[target.json](reference/current/target.json) 逐项核对，迁移期间没有修改。
原 YAML 和已冻结输入保留；新增 SV 修正使用独立期望或显式兼容模式验收。
收尾检查另核对了 17 个原项目 YAML，以及本轮开始前已有的 630 个参考文件，均未修改。

每项通过相应本地检查后单独提交至 `work`，提交标题描述实际改动。下表的合同与
validation JSON 指明该项的输入 SHA、参数、工具和通过范围，不把历史记录冒称为
最终提交重新运行全部测试的证明。

| 任务 | 提交 | 契约与证据入口 |
|---|---|---|
| 1 DataMem 独立 API | [`746fd78`](https://github.com/Bow-Lin/vectorcgra-v/commit/746fd78) | [DATA_MEMORY_API.md](DATA_MEMORY_API.md) |
| 2 DataMemScalable 独立 API | [`e1e7d8e`](https://github.com/Bow-Lin/vectorcgra-v/commit/e1e7d8e) | [DATA_MEMORY_API.md](DATA_MEMORY_API.md) |
| 3 N 输入 OrLink | [`1556891`](https://github.com/Bow-Lin/vectorcgra-v/commit/1556891) | [LINK_APIS.md](LINK_APIS.md) |
| 4 Selector ready 隔离 | [`9b68ef9`](https://github.com/Bow-Lin/vectorcgra-v/commit/9b68ef9) | [LINK_APIS.md](LINK_APIS.md) |
| 5 PipeQueue 同拍替换 | [`b78dc78`](https://github.com/Bow-Lin/vectorcgra-v/commit/b78dc78) | [PIPE_QUEUE_API.md](PIPE_QUEUE_API.md) |
| 6 VectorAllReduce | [`c75439b`](https://github.com/Bow-Lin/vectorcgra-v/commit/c75439b) | [VECTOR_REDUCE_API.md](VECTOR_REDUCE_API.md) |
| 7 向量进位和 lane 范围 | [`822c938`](https://github.com/Bow-Lin/vectorcgra-v/commit/822c938) | [VECTOR_ARITHMETIC_API.md](VECTOR_ARITHMETIC_API.md) |
| 8 LoopController 握手与父完成 | [`af6432c`](https://github.com/Bow-Lin/vectorcgra-v/commit/af6432c) | [LOOP_CONTROLLER_API.md](LOOP_CONTROLLER_API.md) |
| 9 复位、除法、MAC 等边界 | [`43086d1`](https://github.com/Bow-Lin/vectorcgra-v/commit/43086d1) | [ARITHMETIC_BOUNDARIES.md](ARITHMETIC_BOUNDARIES.md) |
| 10 内存配对和外设重启 | [`c184af2`](https://github.com/Bow-Lin/vectorcgra-v/commit/c184af2) | [MEMORY_BOUNDARIES.md](MEMORY_BOUNDARIES.md) |
| 11 参数化 PE 公共接口 | [`207dc2d`](https://github.com/Bow-Lin/vectorcgra-v/commit/207dc2d) | [PE_INTERFACES.md](PE_INTERFACES.md) |
| 12 NoC 保持与 VC 归一化 | [`0a2625a`](https://github.com/Bow-Lin/vectorcgra-v/commit/0a2625a) | [NOC_HANDSHAKES.md](NOC_HANDSHAKES.md) |
| 13 独立架构配置工具 | [`6970dee`](https://github.com/Bow-Lin/vectorcgra-v/commit/6970dee) | [CONFIGURATION_TOOL.md](CONFIGURATION_TOOL.md) |
| 14 独立程序工具和 barrier | [`3ec6adb`](https://github.com/Bow-Lin/vectorcgra-v/commit/3ec6adb) | [PROGRAM_TOOL.md](PROGRAM_TOOL.md) |
| 15 全量清单和旧 RegFile API | [`34a6027`](https://github.com/Bow-Lin/vectorcgra-v/commit/34a6027) | [MIGRATION_INVENTORY.md](MIGRATION_INVENTORY.md) |
| 16 STORE 与内核完成顺序 | [`3e09c11`](https://github.com/Bow-Lin/vectorcgra-v/commit/3e09c11) | [KERNEL_BOUNDARIES.md](KERNEL_BOUNDARIES.md) |
| 17 完整系统和实际网表 | [`57c370f`](https://github.com/Bow-Lin/vectorcgra-v/commit/57c370f) | [SYSTEM_ACCEPTANCE.md](SYSTEM_ACCEPTANCE.md) |
| 18 统一回归和固定工具链 | [`4be92fd`](https://github.com/Bow-Lin/vectorcgra-v/commit/4be92fd) | [REGRESSION.md](REGRESSION.md) |
| 19 独立包及干净构建 | [`aa5b0e9`](https://github.com/Bow-Lin/vectorcgra-v/commit/aa5b0e9) | [STANDALONE.md](STANDALONE.md)、[DEPENDENCIES.md](DEPENDENCIES.md) |
| 20 文档、范围与证据交付 | 本索引所在的文档收尾提交 | [migration-closeout.json](results/migration-closeout.json) |

## 最终验证范围

原生内核验收包括 18 个 AXPY／GEMM／GEMV 输入或尺寸场景，在两种内存模式、两种
节奏下共 72 次数学验收，检查全部输出、存储次数和返回顺序。最后一次存储与返回同拍
是合法正例。系统验收有 18 次正向、27 次负向运行，包含选定完整 Mesh 和 Ring 的
实际综合网表；相应 RTL 与网表的场景周期一致。组件、PE 以及其他内核的验收入口见上表。

统一回归的 14 组覆盖 48 个目标，原 Python 源码分类审计另列。Verilator 5.029、
Yosys 0.45+139、sv2v 0.0.13 由 SHA 固定的归档安装。CI 逐项保留退出码、输入指纹、
日志及负例；完整 Mesh 网表解析需要约 11.4 GiB，建议独占 16 GiB 内存。

实际远端状态按提交和运行单独记录：

`4be92fd` 到 `aa5b0e9` 没有改动原生 RTL、文件清单、配置／程序工具或现有硬件测试；
后者新增工程导出，并调整历史源码获取方式。该基线入口和独立包在后者另行验证。
机器记录列出完整的提交间文件差异，不能把两个提交的构建脚本指纹当成完全相同。

- [`4be92fd` 的统一回归](https://github.com/Bow-Lin/vectorcgra-v/actions/runs/38067845563)：
  **14 组、48 个目标全部通过**，目录检查和原 Python 源码审计也通过；每组的实际目标
  日志、作业状态和 artifact 校验值见机器记录的 `remote_ci`。此前 apt Verilator 5.020
  的 Shifter 周期失败保留在旧记录中，不计入通过结果。
- [`aa5b0e9` 的回归和独立包](https://github.com/Bow-Lin/vectorcgra-v/actions/runs/38069896320)：
  独立包构建验收已通过，CI 导出的归档 SHA 与本地正式包完全一致。各回归组状态另见
  机器记录。[`vectorcgra-standalone` artifact](https://github.com/Bow-Lin/vectorcgra-v/actions/runs/38069896320/artifacts/11676289511)
  含归档、SHA、manifest 和构建日志，CI 保留 14 天；过期后可从对应提交重新生成。

本地干净构建在 Ubuntu 24.04／GCC 13 容器中完成，网络关闭，只挂载解包工程和只读
HDL 工具。容器内没有 Git、原项目 Python 目录或 PyMTL，从空 build 目录运行 current、
配置工具、程序工具、历史 baseline 和 AXPY 组合存储的六个场景及背压／负例。
这是选定干净环境验收，与完整仓库的 14 组回归分开。

正式 `aa5b0e9` 包从干净提交重复生成，均为 **50,187,855 字节**、1,576 个有效载荷文件，
SHA256 为 `6a4f9a73551b4b65b1530801f4e9cba5d64b487040efc729bd3a4cc643d6f15d`。
全部 490 个运行输入与此前容器验收快照相同；947 个基线文件与固定 Git 归档相同。
该 SHA 只标识 `aa5b0e9` 包，不标识包含本索引的新包。最终文档提交改变包的内容与 SHA，
应使用该包旁的 `.sha256` 和包内 manifest 核验，避免自引用的提交／归档哈希。

文档收尾只更新文档和证据索引，检查源文件指纹、源码分类、回归清单、脚本单元测试、
本地文档链接以及导出完整性。它没有再次执行所有硬件仿真；对应硬件证据的提交与源码
范围保留在机器记录中，后续 Actions 状态以具体提交的运行页面为准。

## 交付边界

- `cgra_pe` 是参数化单 PE；`cgra_system`、`cgra_multi`、`cgra_multi_template` 提供
  阵列入口。已测试的 32／64 位、4／8 端口、16／64 PE 和异构 21 PE 是参数点，
  不是任意 FU、VC、credit、拓扑和规模的承诺。完整门级系统采用指定的小深度配置。
- 保留未写 PE 寄存器默认 token、控制步退役、有序 FU 的 last-valid 优先级、旧 RegFile
  无条件写入，以及 Streaming 13 位透明保持锁存。不能为了消除警告而改变这些契约。
- 原生模式修复已确认缺陷；冻结 Python 重放显式选择兼容参数。GEMM／GEMV 的原程序
  只完成前缀验证，原 SPMV 配置生成失败；原生修复程序的数学通过不能改写这些结论。
- LoopController 为独立 API，未接入整机命令路由；DataMemScalable 额外 NoC 口在原
  Python 中也未实现。命令打包不代表经过 Controller／Tile／CtrlMem 的白名单后可达。
- VEC_INC、VEC_INC_COMBINED、REM_CONST 两边均只有定义；20 个软件文件未移植。
  通用 DFG／YAML 编译、任意稀疏删 Tile、运行时隔离重配置、更广 DMA 格式、全部原
  Python 测试、四态全面验证、任意参数形式等价和 FPGA／ASIC PPA 不在本轮完成范围。
- 依赖许可分别适用，尤其 MAC 相关代码的原声明；不能将整个导出包统一解释为项目 BSD。

历史阶段文档、日志和 validation JSON 保留为历史证据。当前入口统一由
[README.md](README.md) 和 [CURRENT_MIGRATION.md](CURRENT_MIGRATION.md) 指向。
