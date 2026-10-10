# 当前 Python → SystemVerilog 升级

目标 Python 固定为 `cd7aad878915e389cecf8cc01ff6987d156bd019`。该提交导入 SV；Python 内容来自父提交 `e3caf6928a4e8c97e6be36574af2520ec92083b9`。原始迁移基线仍为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。`reference/current/target.json` 记录所有 274 个原项目 Python 文件的 SHA-256；本批没有修改这些文件。

最新完成批次为 M23（2026-10-10）：原 4×4 SPMV 映射的原生修复配置通过下述限定范围验收。下一项仍是旧独立 API 的补齐。验收记录中的提交、推送及远端 CI 状态均为记录生成时的快照；实际提交与推送状态以 Git 为准。

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
make -C sv current-kernels
make -C sv current-prefixes
make -C sv native-kernels native-math
make -C sv native-multi native-template current-migration
bash sv/scripts/run_baseline.sh all
```

设置工具路径时使用环境变量或 Make 变量。构建产物和日志位于 `sv/build/current/`；历史回归位于 `sv/build/baseline-cd7aad878915/`。`regression` 包含上列当前验收入口与旧基线 all。历史 phase2/3/4 请通过 `run_baseline.sh` 运行。GitHub Actions 增加原生算术、修复后的 kernel、多 CGRA、异构及当前迁移重放；远端 CI 尚未执行。

本批验收包括：

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
- 独立 LoopController、旧静态 CtrlMem/ConstQueue、RingMultiCtrlMem、DataMem/DataMemScalable、OrLink/Selector/PipeQueue 等完整旧 API 的补齐仍是后续批次；当前 PE/系统功能覆盖不能代替这些独立模块的验收。
- ConstQueue/Crossbar 等变体内部的重复实现，以及 NoC 新版结构优化仍待后续集中重构；当前先以同一验收矩阵保持行为一致。
- 当前工具链仍有 Verilator 的 UNOPTFLAT 诊断；修复未驱动位不表示已完成全部组合环、时序或 FPGA/ASIC 实现验收。

## 旧独立 API 的清单

这些缺口不因当前 PE 或系统验收通过而自动关闭。本轮完成接口盘点，未将旧 API 批量改写成包装器。

| Python 模块 | 当前 SV 边界与后续要求 |
|---|---|
| `controller/LoopControllerRTL.py` | 独立多 CCU、父子完成计数及本地/远程 reset/shadow 广播接口尚未移植；已有 LoopCounter/LoopControl FU 不等价 |
| `mem/ctrl/CtrlMemRTL.py` | 旧静态地址/控制写口，仍读取旧 `.ctrl` 字段，停顿周期也增加 times；不能直接用动态 CtrlMem 顶替 |
| `mem/const/ConstQueueRTL.py` | 静态常量 ROM、循环读指针，原实现没有 reset 分支；当前动态常量队列不是同一 API |
| `mem/ctrl/RingMultiCtrlMemDynamicRTL.py` | 独立 ring+控制存储组合包装层未补齐；系统内部 ctrl ring 覆盖不是接口级验收 |
| `mem/data/DataMemRTL.py` | 独立多读写口、首次读懒预加载契约尚未移植；Python Im2colEngine 使用它，SV Im2col 内存需另作对应性验收 |
| `mem/data/DataMemScalableRTL.py` | 额外 NoC 口在原 Python 中也全部系零；不能将其描述为已支持远程访问的缺失功能 |
| `noc/OrLinkRTL.py` | 原 API 为 N 输入，OR 所有消息的 payload/predicate，不按 valid 屏蔽；SV `tile_link_or` 只覆盖两输入内部接口 |
| `noc/SelectorRTL.py` | 原 Python 仅给选中输入赋 ready，其余没有默认值；后续必须先明确修正契约再验收 |
| `lib/basic/val_rdy/queues.py::PipeQueueRTL` | 满队列同周期出队可替换入队；当前 `cgra_queue` 的 Normal/Bypass 模式不提供这一语义 |

## 工具链证据

Verilator 5.029 的文件驱动 while 循环会错误常量折叠循环外的计数器判断，最小复现见 `reference/current/structure/verilator_counter_repro.sv`。迁移 bench 仅给计数器和覆盖位加 `public_flat_rw` 以阻止误折叠；保留全部 RTL 优化和逐位比较。没有删除覆盖检查，也没有因此修改 Python 轨迹。综合循环转换的另一个独立反例为同目录的 `loop_cast_repro.sv`。
