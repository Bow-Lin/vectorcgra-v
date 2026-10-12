# 迁移清单与独立接口边界

固定 Python 目标为 `cd7aad878915e389cecf8cc01ff6987d156bd019`；历史起点
为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。本轮按 `target.json`
逐一检查了 **274 个原始 Python 文件**，SHA 全部未变。

完整表见 [逐文件、opcode 与命令清单](reference/current/inventory/inventory.md)，
机器可读版本为 [inventory.json](reference/current/inventory/inventory.json)。后者列出
1,576 个类、函数、方法及嵌套更新块的名称和行号；其迁移位置和边界继承所在文件的契约，
`line_trace` 单独标为诊断用途，不能把函数名称对应理解为逐函数等价证明。

## 分类结果

| 类别 | 文件数 | 含义 |
|---|---:|---|
| 有直接 RTL 对应 | 72 | 参数、语义差异和集成范围仍受各接口文档约束 |
| 已内联的公共功能 | 4 | FU 基类、SumUnit、ReduceMulUnit、Register 队列链 |
| 有限组合工厂 | 4 | 已实现项目使用的具体组合；没有任意 Python 子类组合 API |
| ABI／元数据 | 6 | 编码、类型和字段布局，不代表每个编码可执行 |
| 有限软件工具替代 | 9 | 架构／程序 JSON 工具，不是通用 YAML／DFG 编译器 |
| 未移植的软件 | 20 | DFG／映射、日志、CI、PPA、自动化脚本等，保留原文件 |
| Python 框架接口 | 2 | SV 使用展开的信号；FL／CL 适配器不导出 |
| FL／CL 参考模型 | 4 | 不是需要再实现一份的可综合 RTL |
| 原始测试 | 93 | 列出关联验收族；不声称这 93 个测试全部执行或通过 |
| 测试辅助模块 | 4 | Source／Sink 驱动与检查器 |
| 包初始化 | 56 | Python 包组织，无新增硬件 API |

计数表示清单无遗漏，**不表示行为正确率或测试通过率**。关联 evidence 仍保留原批次的
源文件哈希与参数；清单引用历史证据不会把它变成当前源码的新验收。
PyOCN、HardFloat、外部 HDL 和工具链不在这 274 个文件分母中；它们有独立来源和许可范围。

## 编码、可执行功能与系统可达性

- **99 个原始 opcode** 全部编码一致；**4 个原生扩展**为 ULT=102、ULT_CONST=103、
  PHI_N=104、PHI_START_PRED=105。扩展没有覆盖原始编码。
- VEC_INC=50、VEC_INC_COMBINED=70、REM_CONST=99 在原 Python 中只有定义，
  SV 同样没有实现；不能列为 Python 已实现而 SV 遗漏的算术。
- AND_CONST=100、OR_CONST=101 在 Python 仅有定义，SV Logic 已实现，属于在既有编码
  上增加功能。START=0 是控制哨兵，不能当作普通算术指令。
- 浮点／向量 RTL 有数字和局部常量 dispatch；扫描宏名不充分。清单显式补充了这些位置。
  源码引用不等于 opcode 被测试，也不等于当前 PE 的 FU catalog 包含对应执行单元。
- **59 个命令**全部列出。PAUSE／TERMINATE／RESUME／PRESERVE、lower-bound 和 PHI
  地址记录仅由 Context 的主机入口接受；Context／Streaming 入口没有接收 loop lower／upper／step。
  Streaming 配置必须有 StreamingMem FU 才产生实际作用。
- LC_* 是独立 LoopController API，尚无整机路由；LoopCounter 的 shadow/reset/complete
  是 sideband 契约。Controller 的配置转发实际使用白名单。程序工具能打包编码，不保证
  该命令在任意顶层可达；需遵守完整表中的方向和变体约束。

## 本轮补齐：旧 RegFile 包装接口

`rf/RegFile.py` 此前只有底层 `cgra_register_file`，缺少 val/rdy 包装。
新增 `rtl/common/cgra_reg_file.sv`，对应原单读／单写接口，参数为 DATA_BITS、DEPTH、ADDR_W。
它没有接入当前 PE，当前 PE 仍使用带控制步 token 语义的 RegisterCluster。

这是原接口的兼容实现，保留其不常规行为：每个上升沿无条件写入，写入不受 valid、ready
或 reset 控制；三个输入 ready 都等于输出 ready，输出 valid 等于读地址 valid。
异步读取，无存储 reset；上电内容不作硬件保证。调用者必须保证地址有效。
不能将该 API 当作会保持背压输出的独立事务存储器。若需要握手写入，应选 DataMem API。

3 组参数（32 位／1 项、67 位／3 项、19 位／16 项）各在 RTL 和真实综合网表运行
640 次独立检查，共 3,840 次。覆盖无效输入写入、reset 写入、背压写入、写前／写后读取、
全部数据位；6 次错误结果注入均失败。3 份网表综合前后 check 及重新读取后 SCC=0。
这是根据原源码契约构造的独立检查，不冒称原 Python test 的逐周期重放。
证据见 [reg_file_validation.json](reference/current/inventory/reg_file_validation.json)。

## 保留的能力边界

任意 FU 工厂和通用 DFG 编译软件没有一对一替代。SumUnit／ReduceMulUnit 的算术在
VectorAllReduce 内联，没有额外导出任意输入数的独立类接口。DataMemScalable 的额外 NoC
端口在 Python 与 SV 都未实现远程访问。LoopController 系统调度、任意 VC／credit、
稀疏删除 Tile、运行时隔离重配置及更广 DMA 格式仍属于另行确认的扩展。

复位、算术、向量进位／归约、FP、NoC 锁定／VC、DMA／im2col 的原生修正分别见
[算术边界](ARITHMETIC_BOUNDARIES.md)、[向量算术](VECTOR_ARITHMETIC_API.md)、
[归约](VECTOR_REDUCE_API.md)、[PE 接口](PE_INTERFACES.md)、
[NoC](NOC_HANDSHAKES.md)、[存储边界](MEMORY_BOUNDARIES.md)。
显式 legacy 模式的逐位通过不代表原生模式逐周期等价，也不能证明原 Python 本身数学正确。

## 复核

```bash
python3 sv/migration_tools/inventory.py --check
make -C sv current-reg-file current-reg-file-synth
```

库存检查只用标准库，以 AST 读取固定源，不 import／运行 PyMTL；检查所有源 SHA、
分类无遗漏、符号、目标文件存在以及原始编码一致性。修改映射后先不带 `--check` 重新生成。
该审计需要完整原仓库，独立 SV 导出可携带结果，不需携带或执行原 Python。
