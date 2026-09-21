# 第三阶段：完整 FU 与 Tile 变体迁移

基线为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`，工作分支为
`codex/sv-migration`。本阶段从第二阶段收尾 `786b732` 继续，已完成
实现、回归与证据归档。原 Python RTL、原 NoC 优化分支和 master 均不修改。

## 可以直接维护的硬件

新增顶层 `rtl/cgra/cgra_programmable.sv` 在 SV 构建时选择 FU 列表和 Tile
类型，内部仍使用原 Controller、控制环、数据 bank 和通信协议。
`cgra_scalar`/`cgra_2x2` 保留原有使用方式。日常构建直接编译 `rtl/`，
不运行项目 Python 或 PyMTL；迁移期间的 Python 只用于冻结参照、生成取证
数据和汇总结果，保存在 `migration_tools/`。

| 模块组 | 直接维护的实现 |
|---|---|
| 原有四 FU | Adder、Mul、Mem、Nah，继续使用第二阶段实现 |
| 其余 15 个标量 FU | Const、Comp、Logic、Shifter、Sel、Phi、Grant、Gep、ExtractPredicate、Ret、LoopCounter、LoopControl、Div、InclusiveDiv、ExclusiveDiv |
| 向量 FU | VectorAdderCombo、VectorMulCombo、VectorAllReduce，以及向量加/乘子模块 |
| 组合 FU | SeqMulAdder、SeqMulShifter、PrlMulAdder、ThreeMulAdderShifter、FourIncCmpNotGrant |
| 定点 MAC | 16 位 ALUgenMAC 接口、native core 和可综合部分积乘法器 |
| 浮点 FU | FP 加/减/常量加/增量与乘/常量乘封装，复用冻结的 HardFloat HDL |
| 流式访存 | StreamingMem 的请求、响应、步长、完成及控制状态 |
| Tile | Base、ContextSwitch、StreamingLoad；两个变体含其完整局部存储、crossbar 和控制逻辑 |

FU 目录提供 31 个可选择种类；编号定义在
`rtl/common/cgra_fu_catalog.svh`，仅用于构建时选择硬件，**不是运行时操作码**。
`FU_KINDS[8*i +: 8]` 表示第 i 个 FU，必须保留顺序；原聚合器对多个有效
输出采用最后一项优先，ready 按位 OR。没有新增流水级或改变该选择规则。

例如五 FU 顺序 Adder、Mul、Mem、Logic、Nah 对应：

```systemverilog
`include "cgra_fu_catalog.svh"
cgra_programmable #(
  .COLS(2), .ROWS(2), .DATA_W(32),
  .FU_COUNT(5),
  .FU_KINDS({`CGRA_FU_NAH, `CGRA_FU_LOGIC,
             `CGRA_FU_MEM, `CGRA_FU_MUL, `CGRA_FU_ADDER})
) accelerator (/* 原顶层端口连接 */);
```

编译 DUT 使用 `filelists/phase3.f`。默认仍是四 FU 的 2×2 Base Tile。
`TILE_VARIANT=1` 选择 ContextSwitch，`TILE_VARIANT=2` 选择 StreamingLoad。
已验证的 Context 配置为四端口；Streaming 使用原架构的八端口 KingMesh，
四个额外方向依次为 NW、NE、SE、SW。对角边界按基线终止，不新增外部接口。
四端口控制字保持 119 位，八端口为 143 位，对应测试各自使用独立原始类型
和配置包，不能把两种配置的打包字直接互换。

原 FlexibleFuRTL 构造子 FU 时使用默认 vector factor，因此组合顶层明确
要求 `VECTOR_FACTOR_POWER=0`；独立 FU 保留各自参数。不允许多个 MemUnit
争写同一 Tile 访存接口。MAC 要求 16 位，流水除法要求 32 位；这些限制
来自原硬件或本阶段确认的合法构造，不能由“可配置”推定任意组合已验证。

## 验证方法与已执行结果

组件测试同时使用冻结参照和独立数学/事务预期。能执行原 Python 的模块
另保存原始输入/输出逐周期轨迹；外部 Verilog IP 使用独立原 HDL 参照。
比较包含无效周期的消息，没有按 val 动态屏蔽输出。Verilator 为二态
模拟器，有限测试不等于所有程序、参数和四态初始化的形式证明。

| 验证组 | 已执行覆盖 |
|---|---|
| 标量 32 位 | 15 模块 × 2,881 周期 × 303 原始输出位；13 项同时核对原 Python；929 数学检查、32 流水结果 |
| 标量 64 位 | 13 模块 × 3,105 周期 × 424 位；950 数学检查 |
| FP | 加/乘各两种格式；每组 1,170 次全输出对照，160 个有限数运算和八个特殊值检查 |
| 向量与组合 FU | 30 组配置各 640 周期，共 19,200 次原始输出对照及 19,200 项独立算术检查；覆盖 32/64 位及多个 lane 数 |
| MAC 部分积 | 九组位宽共 18,432 样本；两路部分积均与原模型逐位相同，另核对 signed/unsigned 乘积 |
| Context Tile | 210 周期；12 个输出，首轮六个另有独立预期；两次完成、TERMINATE 清空已满通道 |
| Streaming Tile | 190 周期；十次地址/数据传输、两次完成、请求/响应反压和中途复位 |
| 完整 Base/Logic/FP CGRA | 每种 134 周期 × 489 位；四 Tile、四条链路、跨 bank 存取、多播、反压及复位重配 |
| 完整向量 CGRA | 134 周期 × 489 位；逐 8 位 lane 加法、标量乘法、四 Tile 闭环；结果 `84ff0004` / `04080a7e` |
| 完整 Context CGRA | 134 周期 × 489 位；两轮结果 28、−11，八个完成包及四个主机读响应 |
| 完整 Streaming CGRA | 160 周期 × 513 位；两条对角链路；两轮各五个结果、八个完成包及四个主机读响应 |

Base 和 FP 程序是 `(输入+5)×3−8`，两轮结果为 28、−11。Logic 程序是
`(~输入)×3−8`，结果为 −32、7。FP 预期按实际基线格式独立编码；该项不
声称存在纯 Python oracle。系统负控实际注入错误结果及永久反压，要求
模拟器非零退出并匹配指定报错，避免把未运行或任意崩溃计作通过。

向量程序先逐 8 位 lane 加 `05040302`，再作 32 位标量乘三，最后逐 lane
加 `f8f9fafb`。Streaming 两轮输出分别为 `[10,13,16,19,22]` 和
`[-8,-5,-2,1,4]`。

六种完整 CGRA 都通过 sv2v → Yosys `synth -noabc` → `check -assert`，
各自保留全部 41 个原顶层端口。四端口配置输入/输出总位数为 702/685，
八端口为 750/733；此处包含仿真固定排除的外部 NoC 端口。28 组非 MAC
向量/组合模块另通过展平及完整通用综合，七组 MAC/乘法器通过前端和
结构检查。早期未驱动警告及失败与最终检查为零分开保存。

公共 profile 修改后的第二阶段回归也通过：2×2 为 134×489 位，3×2 为
158×563 位，4×4 为 286×789 位，64 位配置为 134×770 位。原 3×2 的
错误结果和永久反压负控再次通过；非法组合 vector factor 参数也在指定
guard 处被拒绝。3×2 仅保留原架构已有支持，没有新增非方形能力。

完整汇总为 `results/phase3-summary.json`。原始日志与结果归档在
`results/phase3-evidence.zip`，503 个条目、10,893,363 字节；逐条从压缩包
读回核验，清单为 `phase3-evidence-manifest.json`。本阶段分为参照提交
`9daf3ec`、实现提交 `d71a2bb`、测试提交 `17aaefa`，最终文档与证据另作
收尾提交。可以按提交比较或切回第二阶段 `786b732`。

## 必须保留并明确说明的基线差异

1. **FP 默认格式不是 IEEE binary32。** ac96 的 8/23 参数实际向 HardFloat
   传入 expWidth=9、sigWidth=23。FINC 常量在两种测试格式中都表示 0.5。
   本次保持硬件行为；FP 格式修正应单独立项，否则会改变程序结果。
2. **VectorMulCombo 的 Python/HDL 有已存在差异。** 32 位、四 lane、opcode
   75、两个输入均为 `0x100` 时，原 Python 得 `0x10000`，原翻译 HDL 得
   `0x1`。原因是 HDL 位移量乘法截为四位。本次兼容原 HDL，不声称两种
   原参照彼此等价；最小复现和原始结果独立保留。八 lane 时原实现只路由
   前四个 lane 的问题也保留。
3. 部分原 PyMTL 构造不能直接翻译。标量使用有明确补丁、原 Python 逐周期
   对照的隔离适配器；PrlMulAdder 使用合法 Ctrl2 参照及显式字段映射；
   Context/Streaming Tile 使用未改 Python 原始轨迹。各自来源标签不同，
   不将这些结果统称“未改源码直接导出的 HDL”。
4. 原 Streaming Tile 的四端口构造存在类型不匹配；本阶段采用原测试已有
   的八端口 KingMesh，没有为通过测试静默修复 Python。
5. 原除法的除零域、部分状态未复位、锁存器和未驱动信号保留，不通过补零
   改变语义。单 CGRA 三个原本未驱动的外部 NoC 输出仍作固定排除，其他
   活动接口逐位检查。最终 Yosys check=0 不代表源 RTL 没有未定义域。
6. MAC 原乘法依赖是仅仿真模型。本次补可综合的等价部分积实现，原 vendor
   只作参照并保留原始许可声明；迁移不改变已有 IP 的授权条款。

各组细节、失败过程、来源 SHA 和执行命令分别见
`tests/phase3/{scalar,vector_combo,float,tile_variants}/`、`reference/phase3/`
与 `EXPERIMENT_LOG.md`。本阶段没有重新测量标准单元面积或最高频率，
不能把 generic cell 数量当作面积，也不沿用此前不同配置的 NoC 优化数字。

## 日常运行

从迁移工作树根目录运行全部第三阶段仿真：

```powershell
& ./sv/scripts/run.ps1 -Task phase3 `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

只跑完整 CGRA 程序使用 `-Task phase3-system`；组件可选择
`phase3-scalar`、`phase3-vector-combo`、`phase3-float` 或 `phase3-tiles`。
阶段三 shell 入口按本机 MSYS2 UCRT Verilator/Clang 环境验证；没有声称已
在其他操作系统实跑。所有用例均在 `sv/tests`，参考数据不在 DUT 文件列表中。

完整 CGRA 通用综合单独运行：

```powershell
& ./sv/tests/phase3/system/check_synthesis.ps1
```

此命令使用 sv2v、Yosys `synth -noabc` 和 `check -assert`，不做 PPA 比较。
FP、Tile 变体和其他组件各自的综合/结构入口见对应 README。

接下来的第四阶段是多 CGRA mesh/ring、异构系统、跨 CGRA 任务迁移和
DMA/im2col；第五阶段再完成全项目功能清单、配置工具和交付回归。单 Tile
上下文恢复的验证不能替代跨 CGRA 任务迁移验证。
