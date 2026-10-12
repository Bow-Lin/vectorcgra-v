# 当前 Python → SystemVerilog 迁移状态

本轮按 [已授权的 20 项顺序](MIGRATION_TASKS.md) 完成功能补齐、语义检查、回归和独立
交付。任务完成指这些明确范围完成，不表示所有 Python 软件工具被重写，也不是任意
参数组合的形式等价证明。具体提交和验证状态见 [最终验收索引](FINAL_ACCEPTANCE.md)。

Python 目标固定为 **`cd7aad878915e389cecf8cc01ff6987d156bd019`**；它导入 SV，Python
内容来自父提交 **`e3caf6928a4e8c97e6be36574af2520ec92083b9`**。最初基线仍是
**`ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`**。迁移期间原 274 个 Python 文件、
原始 YAML 和冻结参考保持不变；`reference/current/target.json` 固定 Python 源文件的 SHA，
其余完整性核对见最终验收记录。

## 实现与接口

- `cgra_pe` 是一个参数化 PE，统一 Base／Context／Streaming 入口；阵列规模由上层
  `cgra_system`、`cgra_multi` 或 `cgra_multi_template` 构造，不受固定 2×2 顶层限制。
- 公共参数、类型、PE 端口及 FU 内存连线已集中维护；保留各变体的命令、退役、任务
  保存／恢复与 Streaming 语义。详见 [PE_INTERFACES.md](PE_INTERFACES.md)。
- 独立 DataMem、DataMemScalable、OrLink、Selector、PipeQueue、RegFile，以及静态
  CtrlMem／ConstQueue、RingMultiCtrlMem 和 LoopController 有独立 API 与验收。
  独立 API 不自动表示已替换 PE 内部对应模块或接入整机。
- 标量、向量、归约、组合、MAC、浮点、存储、DMA／im2col、NoC 的修复和边界分别
  记录在接口文档中；[MIGRATION_INVENTORY.md](MIGRATION_INVENTORY.md) 提供完整索引。
- JSON 架构／程序工具不导入原项目或 PyMTL，生成静态参数、控制包、常量、预加载和
  barrier。它们是有范围的软件替代，详见 [CONFIGURATION_TOOL.md](CONFIGURATION_TOOL.md)
  与 [PROGRAM_TOOL.md](PROGRAM_TOOL.md)。
- 新增已映射 ReLU YAML 的有限前端和直接运行入口，支持上传文件的 4×4／II=5／
  32 元素组合内存配置，检查完整回读和写入完成顺序。见 [YAML_RELU.md](YAML_RELU.md)。

## 原生修正与 Python 兼容

原生默认行为与冻结 Python 周期重放分别验收。旧轨迹显式启用所需的 NOC、MEMORY、
ARITH、VECTOR、FP、REDUCE 兼容参数；不能把通过兼容重放等同于修复后的默认语义。

| 范围 | 当前语义和证据 |
|---|---|
| 存储与完成顺序 | 假谓词 STORE 正常退役且不发事务；reset／clear 抑制原生内存事务；内核返回必须等待实际存储完成，最后一次写入与返回同拍合法。见 [KERNEL_BOUNDARIES.md](KERNEL_BOUNDARIES.md) |
| 算术／浮点 | 修正常量握手、边界运算、MAC 有符号行为；浮点默认使用 IEEE 字段映射和独立结果检查，旧格式显式兼容。见 [ARITHMETIC_BOUNDARIES.md](ARITHMETIC_BOUNDARIES.md) |
| 向量／归约 | 组合常量的 lane 间进位、乘法 lane 范围、归约请求与返回背压稳定性有独立验收。见 [VECTOR_ARITHMETIC_API.md](VECTOR_ARITHMETIC_API.md)、[VECTOR_REDUCE_API.md](VECTOR_REDUCE_API.md) |
| LoopController | 独立接口修复满目标派发回绕、背压输出保持和同拍完成计数；父通知及身份契约有限定。见 [LOOP_CONTROLLER_API.md](LOOP_CONTROLLER_API.md) |
| 内存／外设 | 配对握手、非对称端口、复位、DMA 长度及重启、im2col 边界与系统回读。见 [MEMORY_BOUNDARIES.md](MEMORY_BOUNDARIES.md) |
| NoC／Controller | 包在背压下保持，Ring VC 选择归一化；禁用 im2col 的 ready 显式绑零。见 [NOC_HANDSHAKES.md](NOC_HANDSHAKES.md)、[SYSTEM_ACCEPTANCE.md](SYSTEM_ACCEPTANCE.md) |

有意保留的接口行为同样必须遵守：未写过的 PE 寄存器提供默认 token；操作数可以在
同一控制步中多次观察，常量和寄存器消费随 `ctrl_proceed` 退役；有序 FU 选择保留
last-valid 优先级。独立旧 RegFile 包装每个时钟沿无条件写入，不能当作普通握手 RAM。
Streaming 的透明控制包保持逻辑在选定网表中保留 13 位锁存，不声称全部消除了锁存器。

## 验证范围

- 独立单元／PE：除数学结果，还检查背压、缺失输入、reset／clear、非法参数，并运行
  错误期望或恢复旧缺陷的负例。选定综合网表另有重新读取后的 check／SCC 检查，
  覆盖范围以各组证据为准。
- 原生 AXPY／GEMM／GEMV：18 个输入／尺寸场景 × 2 内存模式 × 2 节奏，共 72 次数学
  验收，检查完整回读、实际写次数和返回顺序。SPMV 的 nnz=0…8 及独立 COO 另有证据。
- 当前整机：16／64 PE 同构系统、21 PE 异构系统，以及选定完整 Mesh／Ring 网表；
  18 次正向运行、27 次负向检查。两份整机网表与对应 RTL 的场景周期一致。
- Python 周期兼容：AXPY、FIR、histogram、ReLU、SAD 五个已完成轨迹；global_add、
  dynamic_fir 两个完整多 CGRA 场景。GEMM／GEMV 只验证原 Python 未完成的前缀，
  不标成原 Python 完成；原 Python SPMV 配置生成失败，原生修复程序另行验收。
- 本地与 CI 的统一清单为 14 组、49 个目标，工具版本和 SHA 固定。每组保存输入 SHA、
  退出码和日志；来源审计与原生功能回归分开。详见 [REGRESSION.md](REGRESSION.md)。
- 独立包以不含原项目 Python／`.git`／PyMTL 的干净环境另行检查，来源与许可保留。
  详见 [STANDALONE.md](STANDALONE.md)。

每份 validation JSON 保留其运行时的源码、参数和工具版本。历史记录不会因被新文档
引用而变成当前版本重新运行的证明；最新统一回归和独立构建状态见最终验收记录。

## 参数与未覆盖范围

Base／Context 采用 4 或 8 个物理端口，Streaming 采用 8 个；CTRL_DEPTH／REG_DEPTH
至少为 2，1 ≤ NUM_CTRL ≤ CTRL_DEPTH。有序 FU 列表恰含一个 Nah，内存 FU 的数量和
类型受变体限制。32／64 位 PE、非方形阵列、异构 FU、4×4 单阵列及 64 PE 多阵列是
已测试参数点；不要把这些点推广为任意位宽、端口数、FU 排列和拓扑均已验证。
完整整机门级验收使用 CTRL_DEPTH=2、REG_DEPTH=2 的指定 Mesh／Ring 配置。

[完整清单](reference/current/inventory/inventory.md) 分类 274 文件、99 个原始 opcode、
4 个原生扩展和 59 个命令。它是覆盖清单，不是测试通过率。需明确保留的边界包括：

- LoopController 尚无整机命令路由；DataMemScalable 的额外 NoC 口在原 Python 中也未
  实现，SV 保留该边界。命令转发使用显式白名单，不是自动 catch-all。
- VEC_INC=50、VEC_INC_COMBINED=70、REM_CONST=99 在两边均只有编码定义。
  AND_CONST=100／OR_CONST=101 为 SV 已实现的原有编码；102…105 为原生新增指令。
- 20 个 DFG／映射、日志、PPA、自动化等 Python 软件文件未移植；没有通用 YAML／DAG
  编译器、任意稀疏删 Tile、运行时隔离重配置或任意 VC／credit 参数承诺。
- DMA 及向量／浮点、矩阵／稀疏程序各有输入格式和尺寸边界，使用前须查对应文档。
- 未重跑全部原 Python 测试，未进行任意参数形式等价、四态全面验证或平台 PPA 签核。

本轮之前的逐批日志和差异说明保留在 [历史迁移记录](CURRENT_MIGRATION_HISTORY.md)。
