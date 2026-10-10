# 当前 Python → SystemVerilog 升级

目标 Python 固定为 `cd7aad878915e389cecf8cc01ff6987d156bd019`。该提交导入 SV；Python 内容来自父提交 `e3caf6928a4e8c97e6be36574af2520ec92083b9`。原始迁移基线仍为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。`reference/current/target.json` 记录所有 274 个原项目 Python 文件的 SHA-256；本批没有修改这些文件。

最新完成批次为 M26（2026-10-10）：补齐独立 RingMultiCtrlMem 动态控制环 API，保留原 Python 对照，原生修正虚假返回源导致的 COMPLETE 饥饿和返回口背压稳定性。M24／M25 独立 API 与 M23 原 4×4 SPMV 的限定范围验收继续保留。下一项是独立 DataMem／DataMemScalable。验收记录中的提交、推送及远端 CI 状态均为记录生成时的快照；实际提交与推送状态以 Git 为准。

## 已实现

| 项目 | 当前实现 |
|---|---|
| 单 PE 顶层 | `rtl/tile/cgra_pe.sv`，`VARIANT=0/1/2` 选择 Base/Context/Streaming；`cgra_programmable` 和 `cgra_system` 共用此入口 |
| opcode | `rtl/common/cgra_opcodes.svh` 集中定义当前 Python 编码；同步 13 个编码变化，包括 Streaming Load、GEP、比较和常量移位 |
| Grant | 按 `ctrl_addr` 独立记录 once 状态；支持 GRT_ONCE_CONST；Context 的 task clear 清除 Grant 状态 |
| 常量移位 | LLS_CONST 的算术、谓词和常量握手 |
| GEP | 当前编码及命令 43 的 Controller → Tile → CtrlMem → FU 配置通路；三变体共用验收 |
| STORE | 普通 STR 的地址和数据请求受两个操作数的 predicate 控制 |
| 常量队列 | 记忆 FU 提前消耗，整条控制步退役时只前进一次；Base/Context/Streaming 同步 |
| RegisterCluster | 依据实际物理输入槽决定是否 drain；向已占用寄存器写入时正确背压 |
| Crossbar | prologue 不消耗输入、不发送陈旧数据、不等待被跳过端口；保留多播单次交付 |
| VectorMul | 修复翻译时位移量位宽截断，采用 Python 的完整整数位移 |
| DMA | 默认正确的 beat 拆装；DRAM 位宽、word index、地址步长、尾拍 mask 参数化；集成封装透传 DRAM_DATA_W |
| Linux 工具链 | 27 个历史 shell runner 去除 MSYS 路径硬编码；新回归直接运行原生 SV |
| 原生算术修正 | SUB_CONST 默认消耗常量端口；浮点默认采用标准 IEEE 字段映射，支持显式旧 Python 兼容模式 |
| 程序工作流 | 从未修改的原始 YAML 测试获取配置包和逐周期参考，生成原生 SV 重放；原测试 Sink 断言继续生效 |

## PE 配置契约

`cgra_pe` 只实例化一个 PE。`COLS/ROWS/MULTI_COLS/MULTI_ROWS` 在此层用于所属阵列的包格式和身份字段，不会生成额外 PE。阵列生成由上层 `cgra_system` 等负责。

- Base/Context 可用 4 或 8 个物理端口，Streaming 要求 8 个。
- `DATA_W`、`CTRL_DEPTH`、`REG_DEPTH`、`NUM_CTRL`、`TOTAL_STEPS` 控制数据和存储配置；控制深度允许非二次幂，例如 YAML 程序的 6。
- `FU_COUNT` 与 `FU_KINDS[8*i+:8]` 给出有序 FU 列表。必须恰有一个 Nah，最多一个连接存储的 FU。聚合器沿用有序 last-valid 优先级，不假定所有组合都满足 one-hot。
- 数据操作数保持可在同一控制步内多次被观察；寄存器 token 和常量指针在 `ctrl_proceed` 退役。未写过的寄存器仍提供原模型的默认 token。
- 已验收参数点：Base 32/4 端口、Base 64/4 端口/CTRL16/REG8、Context 32/4 和 8 端口、Streaming 32/8 端口。更多组合不能仅凭“参数化”视为通过。

## 验证入口

```bash
make -C sv current
make -C sv current-synth current-post-synth
make -C sv current-loop-controller current-loop-controller-synth
make -C sv current-static-memory current-static-memory-synth
make -C sv current-ring-ctrl-memory current-ring-ctrl-memory-synth
make -C sv current-kernels
make -C sv current-prefixes
make -C sv native-kernels native-math
make -C sv native-multi native-template current-migration
bash sv/scripts/run_baseline.sh all
```

设置工具路径时使用环境变量或 Make 变量。构建产物和日志位于 `sv/build/current/`；历史回归位于 `sv/build/baseline-cd7aad878915/`。`regression` 包含上列当前验收入口与旧基线 all。历史 phase2/3/4 请通过 `run_baseline.sh` 运行。GitHub Actions 增加原生算术、修复后的 kernel、多 CGRA、异构及当前迁移重放；远端 CI 尚未执行。

M21–M23 的 PE／系统验收包括：

- 8 个 FU × 539 周期，比较全部 303 位输出（包括无效周期消息；Adder 显式启用 SUB_CONST 的旧 Python 兼容模式），覆盖新编码、predicate、背压、Grant 槽状态、GEP stride 和 VectorMul。
- 故意破坏期望值的负向测试，确认比较器能够检出错误。
- 非法 PE 变体和越界控制计数必须在启动时报错，编译失败不算负向测试通过。
- 常量提前接受/延迟退役、prologue 陈旧输入、未使用物理槽、满目标寄存器，以及多播部分接受后的去重。
- 五组 PE 参数配置运行 Grant + 独立路由背压及 GEP 程序；Context 另验证 TERMINATE 后重新执行。
- Streaming Load：190 周期，10 次请求、10 个输出、2 次完成，独立检查请求地址和结果。
- DMA 32/96/128/256 位 DRAM，零长度、跨 beat 和所有尾拍 mask、独立请求/响应背压及完成背压；集成 DMA 128/256 位 CPU 命令、SPM 回读与 DRAM 回写端到端测试。
- 默认 PE 的 497 个未驱动位已消除。根因包括 19 个窄有符号循环边界转换，在 sv2v/Yosys 路径中导致循环体被删除，以及未使用的接口没有显式驱动。现在在 `proc; opt_clean` 后、综合优化前执行 `check -assert`，综合后再次检查。五组 PE 参数的真实综合网表重跑相同公共接口程序，不只检查最终网表是否有告警。证据和最小反例在 `reference/current/structure/`。
- 历史 all：类型编码、2×2 的 134 周期/489 位比较、错误结果和超时负向测试、通用综合。

YAML 每个程序的 Python 状态、参数、配置包和事件见 `reference/current/kernels/*/manifest.json`；对应原生结果见 `build/current/kernels/*/run.log`。这是逐周期等价检查：数学正确性仍受原测试的断言覆盖范围限制，例如 AXPY 原测试没有最终内存回读。

| YAML 程序 | 参考状态 | 完整通过的周期数 |
|---|---|---:|
| AXPY | Python 完成，SV 全部顶层输出逐位匹配 | 290 |
| FIR4x4 | Python 完成，SV 全部顶层输出逐位匹配 | 350 |
| Histogram | Python 完成，SV 全部顶层输出逐位匹配 | 240 |
| ReLU4x4 | Python 完成，SV 全部顶层输出逐位匹配 | 345 |
| SAD | Python 完成，SV 全部顶层输出逐位匹配 | 190 |
| GEMM | 30 分钟时停止；2,258 周期前缀与 SV 逐位匹配，尚无完成包 | — |
| GEMV | 30 分钟时停止；2,689 周期前缀与 SV 逐位匹配，尚无完成包 | — |
| SPMV | 原配置生成器缺少 ICMP_ULT 映射 | — |

`current-prefixes` 只比较 GEMM/GEMV 已采集的前缀，结果名称为 `CURRENT_KERNEL_PREFIX_PASS`，不能当作程序完成。参考工具新增 `--wall-seconds`（默认 1800）和进度输出；部分轨迹始终标记 incomplete。原配置延长到 12,000 周期仍停顿，进一步定位为读后再次读取寄存器，却没有保留已消费 token。GEMM 还缺少 stride=4 配置，当前 Python/SV controller 的接受列表也漏了命令 43；SV 已补齐转发。

## 原生程序的独立数学验收

`migration_tools/native_kernels.py` 在独立目录生成修复配置，不覆盖 `reference/current` 的原轨迹。配置修复通过现有 Register → Routing → Register 通路保留活跃值；单写端口冲突通过将目标寄存器搬到空闲第四个 bank 解决，不放宽全局 token 协议。完成包按照 RetRTL 的接口携带实际控制字，原 YAML sink 的零控制字期望没有沿用。

| 程序 | 原生独立验收 | 内存回读 |
|---|---|---|
| GEMV | 405 周期完成 | 地址 20–23：30、70、110、150 |
| GEMM | 1657 周期完成 | 地址 32–47 的全部 16 个 `C_initial + A×B` 值 |
| SPMV 原 4×4 映射，原生修复配置 | 964 周期完成并回读全部 32 字 | 前 8 字为 `0、2、6、12、20、30、42、56`；其余 24 字不变 |

另有独立 `spmv_coo` 程序：2×2 阵列中的单 PE 执行 8 个稀疏项，数组地址互不重叠，覆盖重复行累加和负权重。206 周期完成，回读 `481、2、123、274`，与独立 COO 计算一致。它与上述保留原 4×4 映射的修复程序分别验收。

GEMM/GEMV/SPMV/独立 COO 的错误期望和永久背压负向测试均要求失败。`make native-kernels` 包含四个程序；`bash tests/current/run_native_kernels.sh spmv` 单独运行 4×4 SPMV、长度边界和故障注入。M22 的失败配置、日志及校验值保存在 `reference/native/kernels/spmv/failure_m22/`。

SPMV 在迁移工具的内存副本中补充 opcode 映射，并使用原生无符号比较 102/103；100/101 是 Python 已定义但未实现的常量 AND/OR。原始 Python 生成失败的证据保留；原 Python 和 YAML 文件未修改。

### M23：原 4×4 SPMV 的修复与边界

- 修正 M22 寄存器改名工具的遗漏：tile 9 的 `$0 → $24` 同时迁移路由 prologue 的物理输入编号 `5 → 8`。否则旧循环中的值会提前进入反馈链，导致地址 2 错误。
- 新增显式原生 `PHI_N=104`，等待所有已配置输入，按顺序选择第一个真谓词；三输入返回合并不再丢弃第三条路径。`PHI_START_PRED=105` 首次保留入口谓词，只在实际接受且完成 vector factor 时更新首次状态。旧 PHI/PHI_START/PHI_CONST 的编码和行为保持兼容。
- 对编译期 `nnz>0` 且为 4 的倍数的无尾项分支，将 tile 4、slot 13 的循环退出 token 保存到 `$24`，slot 7 以它作为返回依赖，避免只检查“余数为零”就返回。
- 用现有路由交叉开关合并两条存储完成链：`3 → 2 → 1 → 5 → 4` 和 `12 → 8 → 4`。token 在 STORE 后的控制步发出；未激活的 STORE 同样推进控制。返回谓词也经过同一个交叉开关，因此必须等两条链都到达才可执行 Ret；没有增加存储或返回 opcode。
- 将 tile 4 的 Ret 从 slot 11 移到 14，使它在 slot 13 接收原循环退出 token 后再接收完成 token。原 slot 14 的 GEP 移到 11，地址临时值放入 `$25`，避免与同周期 `$2` 写入冲突。保留 4×4 布局、15 步 II 和原算术/访存任务。
- `nnz=0…8` 的 9 组长度分别运行常规模式及主机背压/配置间隔模式，共 18 组检查。验收包含全部 32 字、每个输出地址恰好写一次、实际写次数等于 nnz、返回前已完成这些存储握手、返回后不得继续写入。原 8 项在两种模式下分别为 964/3086 周期（包含回读）。
- 五个负向配置分别恢复错误 prologue、旧 PHI_START、二输入 PHI、提前退出条件，或丢弃存储确认；均要求数学/存储协议检查失败或超时。32/64 位 PHI 单元各执行 395 项检查，覆盖输入选择、缺失输入、谓词、长期背压、独立控制槽、clear、vector factor 和旧 opcode 兼容。
- 上述 PHI 检查在 32/64 位实际综合网表上再次通过，优化前和综合后的 `check -assert` 均通过。M23 同时重跑当前组件、五组 PE 网表、五个完整 Python 内核轨迹、原生 GEMM/GEMV/COO、原生算术及浮点旧格式兼容回归，全部通过。M22 的多 CGRA/迁移系统及两个不完整前缀未在本批重跑，验收元数据明确保留其批次来源。

这仍是**原生配置修复后的数学验收**，不是未修改 Python SPMV 的等价完成。原始 workload 的所有数组仍共享基址 0；本组使用 `mem[i]=i` 的恒等行列索引，不能推广为支持任意别名、重复行的并行读改写或任意长度。重复行和负权重由独立串行 COO 程序覆盖。

## 当前系统的重新验收

- 四 CGRA Mesh、Ring、注册存储和 64 Tile：两个输入场景，检查每个 Tile 完成、远程请求/响应、背压、每个存储 owner 的响应顺序和全部回读值。分别为 384、346、374、944 个采样周期；均包含错误值和永久背压负向测试。
- 21 Tile 异构：203 周期，21 个完成、8 次回读、20 个远程请求；使用既有静态架构表及程序、当前 RTL 的数学验收，不比较旧 HDL。
- 当前 Python 跨 CGRA 归约：91 周期 × 1779 位逐位匹配，结果 53、31；35 个配置包、6 个完成。
- 当前 Python 动态 FIR 迁移：165 周期 × 3844 位逐位匹配，结果 2215；126 个配置包、5 次物理边界传输、2 次恢复覆盖。两个迁移程序均有错误结果负向测试。

## 有意修正 Python 缺陷的地方

这些项目与纯 Python 同步明确分开；原 Python 和旧参考未修改。

1. **Streaming 标量控制步死锁**：Python 在 FU 和 FU Crossbar 同周期完成时只读取旧的 `element_done`，导致 FU Crossbar 的完成丢失。`current_streaming_defect.py` 在未修改 Python 上复现：120 周期后 `element_done=1`、`fu_crossbar_done=0`，只输出第一个 grant。SV 对普通操作直接记录 Crossbar 完成，对 STREAM_LD 保持多次输出并识别本周期 FU 完成。`streaming_defect.json` 保存反例，三变体 PE 和流式加载测试分别验收。
2. **未驱动输入**：Base/Streaming 的 constant clear 显式接 0；Context 的 FU 控制地址接实际 ctrl_addr，未使用 raw packet 输入接 0。Context 的 Grant 随 task clear 清除。
3. **GEP 配置接口一致性**：命令 43 扩展到 Controller 和三个 Tile 变体。原 Python controller 实际使用命令白名单，不是 AGENTS.md 描述的 catch-all；遗漏命令会卡住主机配置流。
4. **SUB_CONST**：默认断开无关的第二操作数 ready，正确接受常量；32/64 位独立算术、背压、缺常量、谓词测试通过。叶模块 `tile_adder.LEGACY_SUB_CONST_READY=1` 仅用于原 Python 缺陷复核，当前 PE 使用修正后的默认值。
5. **浮点**：`FP_EXP_W` 表示指数位，`FP_SIG_W` 表示存储的小数位；HardFloat 使用 `EXP_W=FP_EXP_W`、`SIG_W=FP_SIG_W+1`。默认 FINC 加 1.0，valid 不依赖输出 ready；常量操作要求 const.valid 并合并两个谓词。`FP_LEGACY_PYTHON=1` 恢复原有格式及握手并由 FU/PE/阵列参数透传。IEEE FP16/32/64 的加减乘、常量、FINC、舍入、非规格数、零、Inf/NaN 均有独立检查；旧格式另与四组冻结 HDL 做兼容回归。

## 尚未完成及边界

- 未修改 Python 的 SPMV 配置生成仍遇到 `KeyError: ICMP_ULT`。M23 的原生修复程序已通过上述限定范围的验收；原 Python 等价状态仍是配置生成失败。
- GEMM/GEMV 的原始 Python 轨迹仍标记 incomplete；修复配置的数学通过不是未修改 Python 程序的等价完成。
- VectorMul 的 LANES>4 仍有 Python 只连接前四路的边界，本批不将它扩展为任意 lane 算术。
- DMA command 的 `nbytes >> 2` 仍遵循当前 Python。已验收的 SPM word 为 32 位、长度为 4 的倍数；其它 SPM 位宽/非对齐长度没有完整业务语义保证。
- Mesh/Ring、注册存储、64 Tile 和异构程序使用当前 RTL 的独立数学验收；这些结果不等于当前 Python 的完整逐周期等价。当前跨 CGRA 归约和动态 FIR 另有新采集的原 Python 轨迹。历史 64-Tile Python 轨迹不完整的边界仍保留。
- M24 已补齐独立 LoopController 的 payload API；尚未接入系统，没有新增目的路由、通用 DAG 或并发完成无损收集保证。M25 已补齐独立静态 CtrlMem/ConstQueue 的原生与兼容模式；未替换 PE 动态存储。M26 已补齐独立 RingMultiCtrlMem，未增加 Context／Streaming／FU sideband 能力。DataMem/DataMemScalable、OrLink/Selector/PipeQueue 仍待补齐；当前 PE/系统覆盖不能代替这些 API 的验收。
- ConstQueue/Crossbar 等变体内部的重复实现，以及 NoC 新版结构优化仍待后续集中重构；当前先以同一验收矩阵保持行为一致。
- 当前工具链仍有 Verilator 的 UNOPTFLAT 诊断；修复未驱动位不表示已完成全部组合环、时序或 FPGA/ASIC 实现验收。

## 旧独立 API 的清单

这些缺口不因当前 PE 或系统验收通过而自动关闭。M24 完成 LoopController，M25 完成两个静态存储 API，M26 完成 RingMultiCtrlMem；其余保持待迁移状态。

| Python 模块 | 当前 SV 边界与后续要求 |
|---|---|
| `controller/LoopControllerRTL.py` | M24：`cgra_loop_controller` 独立接口通过四组 RTL／网表验收；原生修正满目标派发回绕，Python 模式保留。路由 ID、并发事件和任意 DAG 限制见 [接口文档](LOOP_CONTROLLER_API.md)；尚未接入系统 |
| `mem/ctrl/CtrlMemRTL.py` | M25：`cgra_static_ctrl_mem` 独立 API 已验收；类型字段名适配后对照未修改 Python；原生修正停顿计数、写入配对与复位，支持单槽和无限预算。见 [接口文档](STATIC_MEMORY_API.md) |
| `mem/const/ConstQueueRTL.py` | M25：`cgra_static_const_queue` 静态 ROM 已验收；兼容模式保留忽略 reset，原生增加复位回绕和安全空表。尚未接入 PE |
| `mem/ctrl/RingMultiCtrlMemDynamicRTL.py` | M26：`cgra_ring_multi_ctrl_mem` 独立 API 已验收；原生关闭 dummy 返回源并锁存背压包，兼容模式对照未修改 Python。四组 RTL／网表通过；范围见 [接口文档](RING_CTRL_MEMORY_API.md) |
| `mem/data/DataMemRTL.py` | 独立多读写口、首次读懒预加载契约尚未移植；Python Im2colEngine 使用它，SV Im2col 内存需另作对应性验收 |
| `mem/data/DataMemScalableRTL.py` | 额外 NoC 口在原 Python 中也全部系零；不能将其描述为已支持远程访问的缺失功能 |
| `noc/OrLinkRTL.py` | 原 API 为 N 输入，OR 所有消息的 payload/predicate，不按 valid 屏蔽；SV `tile_link_or` 只覆盖两输入内部接口 |
| `noc/SelectorRTL.py` | 原 Python 仅给选中输入赋 ready，其余没有默认值；后续必须先明确修正契约再验收 |
| `lib/basic/val_rdy/queues.py::PipeQueueRTL` | 满队列同周期出队可替换入队；当前 `cgra_queue` 的 Normal/Bypass 模式不提供这一语义 |

## M24：独立 LoopController

新增 `rtl/controller/cgra_loop_controller.sv`，使用原 payload 配置与事件接口，支持参数化 CCU 数、目标数、数据／控制／地址宽度。它独立于现有循环 FU，尚未实例化到 PE 或阵列。详细编码、握手和限制见 [LOOP_CONTROLLER_API.md](LOOP_CONTROLLER_API.md)。

- 默认原生模式先扩宽下一派发索引再判断结束，修复原 Python 在 4／8 目标填满时重复派发的问题；`LEGACY_DISPATCH_WRAP=1` 用于原样对照，不改变其它事件规则。
- 四组参数为 32 位／8 CCU／4 目标、64 位／3 CCU／3 目标、32 位／1 CCU／1 目标、32 位／8 CCU／8 目标。原四个 Python 测试及扩展事件轨迹合计 2080 个采样周期，除 12 个场景复位周期外，2068 个周期的全部顶层输出逐位匹配。
- 原生模式四组共 993 项独立检查、57 次派发握手，覆盖屏障、父子重启、远程 shadow、64 位高位数值、仲裁、背压、重新启动、中途复位，以及终止后无多余派发。
- 同四组参数的兼容模式和原生模式分别在真实综合网表重跑，总计 8 个网表配置；优化前和综合后 `check -assert` 均通过。16 个错误期望、4 个恢复回绕、6 个非法配置负向运行均按预期失败。
- 参考工具只调用固定的未修改 Python；12 个参考文件重新生成后逐字节一致。原项目 274 个 Python 文件保持不变；M23 系统回归未在本批重跑，不能将本批独立模块结果当作新的系统集成验收。
- Make、PowerShell、完整 regression 和 CI 增加独立入口；当前 native 文件列表可正常 elaboration 既有 PE 测试台。本批的 SHA、日志摘要和范围独立记录在 `reference/current/loop_controller/validation.json`，此前 `reference/current/validation.json` 仍是 M23 快照。

保留的重要原 API 限制：本地完成只按 ctrl_addr 匹配；远程完成广播给全部运行中 CCU；多个同拍完成可能只计一次；未锁定仲裁可抢占背压中的高编号消息；父通知只处理直接父 CCU；输出不含已配置的 tile／CGRA 路由 ID。这些不是本轮新实现的通用跨 CGRA 调度能力。

## M25：独立静态 CtrlMem / ConstQueue

新增 `rtl/mem/cgra_static_ctrl_mem.sv` 和 `cgra_static_const_queue.sv`。
详细参数、配置加载顺序、复位和兼容边界见 [STATIC_MEMORY_API.md](STATIC_MEMORY_API.md)。

- CtrlMem 默认仅在输出握手时消耗预算与推进 PC；配置地址和数据成对握手，保护背压中的当前指令；同步复位清空程序、PC 和预算。支持非二次幂深度、单槽、有限／无限执行以及自定义 opcode 位域。
- ConstQueue 使用构造期固定 ROM，按独立输出握手循环读取，保留完整 payload／predicate／bypass／delay；默认复位回到第 0 项，空表输出无效零值。
- 显式 `LEGACY_PYTHON=1` 复核历史行为。旧 CtrlMem 直接使用当前 `.operation` 类型失败，冻结工具仅将字段名适配为 `.ctrl`，位布局不变；原 Python 文件未改。兼容模式保留背压耗尽预算、未配对写入假握手及忽略 reset，并明确以 initial 零值模拟 PyMTL 上电状态，不声称 ASIC 上电保证。
- 7 组冻结轨迹共 1305 周期、104102 个输出位，包含 84 个 reset 周期，全部逐位匹配；原 ConstQueue 测试原样通过，废弃 CtrlMem 测试不计作通过。5 个原 Python 参数／字段失败边界另存证据。
- 11 组原生配置共 2635 项独立检查；加上 7 组兼容配置，共 18 个配置在 RTL 与真实综合网表各通过一次。18 份网表的优化前和综合后 `check -assert` 均通过。36 个错误期望、8 个历史缺陷复现和 5 个非法地址／参数负向运行均检出预期错误；同输入的 8 个原生缺陷修复检查通过。
- Verilator 对网表位别名／拼接报告 UNOPTFLAT；重新读入 18 份实际网表后 `check -assert` 和 `scc -expect 0` 全部通过，未发现位级组合环。该检查已加入综合网表入口，编译告警仍保留。
- 23 个冻结文件在独立目录再生成后逐字节一致；274 个原项目 Python SHA 未变。Make、PowerShell、完整 regression 与 CI 仿真入口已接入；native 文件列表对既有 PE 台架的 lint/elaboration 通过。
- 本批尚未接入 PE／阵列，没有重跑 M23 系统或 PPA 验收。证据单独保存于 `reference/current/static_memory/validation.json`，旧批次记录保留。下一项是 RingMultiCtrlMem 独立包装层及其控制环／存储接口契约。

## M26：独立 RingMultiCtrlMem 动态控制环

新增 `cgra_ring_multi_ctrl_mem` 与控制字格式适配层，复用既有环和 `ctrl_mem` 状态机。
支持参数化节点阵列、16／32／64 位数据、非二次幂控制存储，以及不同 FU／Tile 端口格式。
完整接口和限制见 [RING_CTRL_MEMORY_API.md](RING_CTRL_MEMORY_API.md)。

- 未修改 Python 即复现包装层把不存在的 FU 返回源固定 valid=1 的问题：每节点有限控制步已全部退役，但持续返回 cmd=0 空包，使 COMPLETE 饥饿。原测试只检查两个控制字且返回 ready=0，没有覆盖这个问题。
- 默认原生模式关闭虚假返回源，并在控制器返回口增加单项队列，保证背压中的完整报文稳定；返回最低增加一拍延迟，峰值每两拍一条。`LEGACY_PYTHON=1` 保留旧缺陷及原有周期行为。
- 原测试加四组扩展 Python 轨迹共 1816 周期，包括 27 个 reset 周期；每种实现比较全部 744012 个输出位，包含 invalid 消息。15 个冻结文件独立再生成后逐字节一致，274 个原 Python SHA 保持不变。
- 四组参数 × 原生／兼容模式的 RTL 和 8 份实际综合网表均通过；每种实现的原生检查合计 4470 项，覆盖完整控制字、窗口、prologue、有限／无限预算、唯一 COMPLETE、终止／恢复、START、复位保留程序、两 VC 回环和饱和背压。18 个错误期望、8 个旧 dummy 缺陷及 3 个非法配置负向运行均检出预期错误。
- 共享环路由器和交换器改为静态输出连接／选择，消除 sv2v 动态数组读写引起的综合膨胀；仲裁和 invalid 消息保持原样。既有 NoC 500 周期、7／17 节点环各 800 周期的全部输出对照通过，收发守恒分别为 361／786／800 包。
- 每份网表均经过完整 `synth -flatten -noabc`，优化前后 `check -assert`，再读入实际输出网表检查零结构问题和零位级组合环。编译告警如实登记，不把功能通过称为零告警或 PPA 改善。
- Make、PowerShell、完整 regression 和 CI 仿真入口已加入；当前 native 文件列表对既有 PE 台架 lint/elaboration 通过。PowerShell 未在本 Linux 环境执行，本批远端 CI 无验收结果。
- 执行语义仍沿用基类：reset 保留程序，运行中重配置没有事务隔离；Context／Streaming／FU sideband 未暴露，不能把接受命令视为具备对应执行能力。新顶层未接入系统，未重跑系统内核或 PPA；下一项为独立 DataMem／DataMemScalable API。

独立证据为 `reference/current/ring_ctrl_memory/validation.json`；此前 M23／M24／M25 记录保留。
验收时提交／推送状态为记录生成时快照，实际状态以 Git 为准。


## 独立 DataMem API（2026-10-10）

新增 `cgra_data_mem`，支持参数化读写口、完整消息位宽及预加载映像。
默认原生模式成对接收写地址／数据，按写口编号处理同址冲突；读端背压时保存
读前写后边界上的完整结果，不阻塞写口；同步复位恢复预加载或零映像。
兼容模式保留原 Python 的无效读触发预加载写、写使能锁存、假写握手和忽略复位，
原 Python 274 个文件不变。接口与限制见 [DATA_MEMORY_API.md](DATA_MEMORY_API.md)。

- 原测试 Source/Sink 断言及两组扩展轨迹共 509 周期、64531 个输出位，
  包含 23 个 reset 周期；RTL 和实际综合网表均逐位匹配，10 个冻结文件再生成一致。
- 4 组原生参数、3 组兼容参数均通过 RTL 与网表；每种实现有 12810 项原生检查。
  14 个错误期望、8 个旧缺陷复现、3 个非法参数／地址负控均检出预期错误，
  同输入的原生缺陷检查均通过。
- 7 份网表均通过完整综合、优化前后 check，以及实际网表重读后的 check 和零 SCC；
  Verilator 网表位别名告警保留。首次网表编译的数组展平连接问题已在台架修复。
- Make、PowerShell、regression、CI 仿真入口及当前 native 文件列表已接入；
  既有 PE 台架 lint/elaboration 通过。PowerShell 与远端 CI 尚无本批运行结果。
- 未替换 PE／阵列已有存储控制器，未重跑系统内核或 PPA。
  独立证据为 `reference/current/data_memory/validation.json`。
  按 [MIGRATION_TASKS.md](MIGRATION_TASKS.md) 顺序，下一项为 DataMemScalable API。


## 独立 DataMemScalable API（2026-10-10）

新增 `cgra_data_mem_scalable`，复用已验收的独立 DataMem 核心；
原生／兼容本地契约相同。未修改的 Python 将 NoC 输出固定为零，
因此新包装层同样不接收 NoC 数据、不产生远程请求；本批没有新增远程访存。
接口与限制见 [DATA_MEMORY_API.md](DATA_MEMORY_API.md)。

- 单独执行 Scalable 原测试和扩展轨迹，509 周期／91092 输出位（23 个 reset 周期）
  在 RTL 与实际综合网表全部匹配；10 个冻结文件再生成一致，274 个原 Python SHA 未变。
- 4 个原生／3 个兼容参数点各通过 RTL 和网表；每种实现 14279 项独立检查，
  包括 NoC 输入持续变化下的零输出和本地存储正确性。23 次负控检出预期错误。
- 7 份真实网表全部通过完整综合、优化前后 check、网表重读 check／零 SCC。
  共享台架和 runner 扩展后，普通 DataMem 的多口及单词配置在 RTL／网表重跑通过。
- Make、PowerShell、regression、CI 仿真和 native 文件列表已接入；既有 PE 台架
  lint/elaboration 通过。没有新的系统内核、远程访问、PPA 或远端 CI 验收结论。
- 独立证据 `reference/current/data_memory_scalable/validation.json`；
  下一项按 [MIGRATION_TASKS.md](MIGRATION_TASKS.md) 补齐 N 输入 OrLink。


## 独立 N 输入 OrLink API（2026-10-10）

新增 `cgra_or_link`，保留原 N 输入 OR 语义：valid 求 OR，所有输入的 payload／predicate
均参与 OR（包含无效输入），无有效输入时输出消息为零，bypass／delay 始终为零，
ready 广播。未替换已有双来源 `tile_link_or`，详细契约见 [LINK_APIS.md](LINK_APIS.md)。

- 原 Python Source/Sink 测试原样通过；3／5／8 输入、16／32／64 位 payload 的
  960 周期、44800 个输出位在 RTL／网表全部匹配，包含 21 个 reset 周期。
- 四组原生配置（含 1 位／单输入）穷举所有 valid 掩码、ready 与 reset 组合，
  每种实现 12516 项独立检查；15 次错误期望／非法宽度负控检出预期错误。
- 4 份实际网表完整综合、优化前后 check、实际网表重读 check／零 SCC 全通过；
  8 个参考文件再生成一致，274 个原 Python SHA 未变。接口提供单输入退化情况，
  原 Python 的未使用 Bits0 声明在该参数下失败，已明确登记。
- Make、PowerShell、regression、CI 与 native 文件列表接入；既有 PE 台架 lint 通过。
  组合链接不缓存独立流，不承诺输入字段变化下的背压保持；未新增系统或 PPA 验收。
- 独立证据 `reference/current/or_link/validation.json`；下一项是 Selector 的未选口 ready 修正。


## 独立 Selector API 与未选口 ready 修正（2026-10-10）

新增 `cgra_selector`，原生模式只有当前选择口可收到输出 ready，其余明确为零；
保留完整选中消息（包括无效字段）。兼容模式显式保留原 Python 的未选 ready 锁存。
它是组合路由，选择信号须由上游保持到握手完成；契约见 [LINK_APIS.md](LINK_APIS.md)。

- 原固定选择 Source/Sink 测试原样通过；动态切换选择轨迹直接复现残留 ready。
  19／35／67 位、3／5／8 输入共 960 周期／44800 输出位，含 21 个 reset 周期，
  在 RTL 和实际网表逐位匹配；8 个参考文件再生成一致，274 个原 Python SHA 未变。
- 原生增加 8 位／单输入，四组配置穷举选择口、valid 掩码、ready 和 reset，
  每种实现 86908 项检查；残留 ready 用例在原生通过、兼容失败。
  18 次错误期望、旧缺陷、非法选择／参数负控均检出预期错误。
- 7 份实际网表全部完成综合、优化前后 check、实际网表重读 check／零 SCC。
  默认分支无 ready 锁存，兼容分支的锁存器是原始缺陷取证的一部分。
- Make、PowerShell、regression、CI 和 native 文件列表接入；既有 PE lint 通过。
  无新系统或 PPA 验收；证据为 `reference/current/selector/validation.json`。
  下一项：PipeQueue 满队列同周期出入替换语义。


## 独立 PipeQueue API（2026-10-10）

新增 `cgra_pipe_queue`：寄存数据路径、组合 ready 传播，满队列同拍出队可接收替换元素，
深度 1 同样成立。默认复位屏蔽握手并清空逻辑队列，兼容模式保留原复位周期写数据及
无效输出行为。已有 Normal／Bypass 队列与系统实例不变；见 [PIPE_QUEUE_API.md](PIPE_QUEUE_API.md)。

- 直接驱动未修改项目 Python，深度 1／2／3／5、8／35／67／19 位共 1255 周期／45517 输出位，
  含 40 个 reset 周期，RTL／实际网表逐位匹配；13 个参考文件再生成一致，274 个 Python SHA 未变。
  未发现该项目包装层的独立原测试，没有把其它实现的测试算成本 API 原测试。
- 四组原生配置每种实现 7328 项独立 FIFO 列表检查，包含顺序、守恒、复位丢弃、长背压，
  每组至少 40 次连续满队列替换；原生／兼容的 8 份实际网表全部通过。
- 全部网表完成优化前后 check、完整综合、实际输出网表重读 check／零 SCC。
  20 次负控覆盖错误期望、复位假握手、非法派生宽度，以及用 Normal Queue 替代时的满替换失败。
- Make、PowerShell、regression、CI、native 文件列表接入；既有 PE lint 通过。
  此队列不隔断 ready 组合路径，无新系统或 PPA 验收。
  证据 `reference/current/pipe_queue/validation.json`；接下来修复 VectorAllReduce 原生语义。

## 工具链证据

Verilator 5.029 的文件驱动 while 循环会错误常量折叠循环外的计数器判断，最小复现见 `reference/current/structure/verilator_counter_repro.sv`。迁移 bench 仅给计数器和覆盖位加 `public_flat_rw` 以阻止误折叠；保留全部 RTL 优化和逐位比较。没有删除覆盖检查，也没有因此修改 Python 轨迹。综合循环转换的另一个独立反例为同目录的 `loop_cast_repro.sv`。
