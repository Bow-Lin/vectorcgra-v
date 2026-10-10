# 算术边界、复位和组合逻辑

本项基于固定 Python 目标 `cd7aad878915e389cecf8cc01ff6987d156bd019`，
不修改其 274 个原始源文件。原生修复与原始周期兼容明确分开：标量除法、
LoopControl 和 ALUgenMAC 用 `LEGACY_PYTHON=1` 选择旧实现；公共 FU／PE／系统
传递 `ARITH_LEGACY_PYTHON`。向量组合 FU 仍使用独立的 `VECTOR_LEGACY_PYTHON`。
这些开关只覆盖各自模块，不是一键恢复整个历史系统。

## 除法

| 模块 | 原生契约 |
|---|---|
| `scalar_div` | 无符号 DIV／DIV_CONST；组合输出；输入、常量和控制随结果一起退役 |
| `scalar_exclusive_div` | 无符号 DIV／REM；32 位；`1 <= LATENCY <= 32`；操作数齐备才启动，捕获操作数／选择／predicate，最终输出握手才退役输入与控制 |
| `scalar_inclusive_div` | 32 位；相同延迟范围；START 返回零并入队一次除法，END 按序取商或余数；容量为 `LATENCY`，包括流水线内和已返回结果 |

零除数的原生结果定义为商全一、余数等于被除数；predicate 按正常规则计算，
没有新增异常端口。原 Python 普通 DIV 和 DIV_CONST 抛出 `ZeroDivisionError`，
因此零除数是明确的原生扩展，不属于兼容轨迹比较的输入域。

流水线各级使用 `floor(i*WIDTH/CYCLE)` 到 `floor((i+1)*WIDTH/CYCLE)` 的
迭代边界，覆盖所有除法位。原来 32 位／3 级漏算最后两位，
`0xffffffff / 3` 得到 `0x55555554`，正确结果是 `0x55555555`。
`LEGACY_PARTITION=1` 保留旧分段；兼容封装显式选择它。

InclusiveDiv 保留源模型的特殊操作数协议：START 和 END 都消费输入 0，
输入 1 仅被读取、**始终不拉 ready**；END 仍要求两个输入 valid，输入 0 可为
原程序中的占位 token。结果及 predicate 来自对应 START，不能用 END 的新数据
覆盖。满容量 START 和无结果 END 停顿；程序必须在容量耗尽前转入 END，
不能以连续超容量 START 指令等待后续 END 自行解锁。
新增结果跟踪和队列改变了原模型未跟踪流水线的周期行为，默认模式不声称逐周期兼容。

原生除法的 reset／clear 取消在途与已返回结果并屏蔽握手；输入和控制源在退役前
必须保持请求。零 selector 映射输入 0，超过四端口范围的 selector 停顿。
向量计数随控制握手推进，背压期间 predicate 不变。独立核心的
`VECTOR_FACTOR_POWER` 范围为 0…7；公共组合 FU 入口仍要求该构建参数为零。

## MAC 与循环 FU

ALUgenMAC 保持固定 16 位接口和八个 opcode。加减乘／乘加按 16 位取模；
LT／GTE／GT／LTE 使用有符号比较，修复以减法符号判断时的溢出错误，
例如 `-32768 < 1`。操作数选择不再依赖结果 ready，默认零值消除原生锁存，
reset／clear 屏蔽事务。全部八种运算继续要求三个操作数 valid，predicate 为
三个输入 predicate 的 AND；原模型的向量因子元数据不影响 MAC predicate，
本项没有赋予它新的向量归约语义。合法 selector 为 0…4，越界值不作为受支持配置。

`scalar_loop_control` 与独立 `cgra_loop_controller` 是不同模块。前者原生模式
分别记录两个输出是否已被接收，只有两个结果均交付才推进索引、消费输入并退役控制。
背压不会重复已接收输出，reset／clear 清除部分交付和索引状态。索引仍按原来的
无符号、`DATA_W` 位模加更新，保留上界比较和 parent predicate；没有新增有符号循环
或通用循环图。`scalar_loop_counter` 只补全一个临时组合变量默认值，保持原始外部行为。

## 公共复位与未驱动信号

`tile_flexible_fu_configurable` 原生边界在 reset 时屏蔽控制、常量、操作数、
控制器原始包以及内存请求／返回的握手，并将输出消息置零。不能把这一公共边界保证
推广为每个历史独立 FU 都已有相同 reset／clear 契约。clear 没有全局替换为 reset，
存储和全局归约继续使用各自的在途响应处理规则。

五种标量组合 FU 的未用子输入、控制字段和输出明确接零，匹配 PyMTL 二态初始化。
不使用 `setundef` 替综合器选择任意值。向量组合加乘原生模式在 reset／clear 时
不产生事务；向量乘法的控制 ready 要求实际有效结果，缺少操作数或不支持的 opcode
不能提前退役。兼容模式保留原行为。

## 验证入口与范围

```sh
make -C sv current-arithmetic-boundaries current-arithmetic-boundaries-synth
```

验证包括原 Python Source/Sink 测试与全部输出轨迹、独立整数数学、零除数、
随机与符号边界、长背压、复位／clear、InclusiveDiv 突发 START／END、LoopControl
异步输出接收、三种公共 PE 的配置／数据／完成接口，以及非法参数和错误预期负控。
组合 FU 另对照冻结 HDL，LoopCounter 对照冻结 Python 全输出。

实际综合网表重新读入执行 `check` 和零 SCC 检查，再运行功能台架。内部向量网线
用 `splitnets` 展开为标量，避免 Verilator 把无位级环的字级别名误判为依赖环；
没有提高仿真收敛上限或关闭 RTL 优化。综合后的组合 FU 台架只移除已被 flatten
消去的私有计数器层级访问，仍检查全部外部位和独立数学；RTL 台架保留内部计数器检查。

原生目录 lint 按合法配置拆成 32 位目录和 16 位 MAC，要求没有 LATCH／UNDRIVEN。
兼容模式有意保留原锁存及无效周期行为。上述有限二态测试与组件网表检查不等于
全系统等价、四态证明、所有参数穷尽或 PPA；完整系统回归安排在后续任务。
逐配置结果、源文件／工具／日志哈希见 `reference/current/arithmetic_boundaries/validation.json`。
