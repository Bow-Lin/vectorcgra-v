# 向量组合加／乘法边界

`tile_vector_adder_combo` 默认修复 opcode 72（组合常量加法）的跨 lane 进位。
`LEGACY_PYTHON=1` 复现原 Python 错误比较 opcode 71、导致 72 不进位的行为。
PE 和系统用 `VECTOR_LEGACY_PYTHON` 统一传递加法／乘法的兼容开关。

加法 opcode 51／52／53／54 分别为逐 lane 加、加常量、减、减常量，每个 lane
独立截断；71／72／73／74 对应连通进位／借位链的全字运算。结果均按 `DATA_W`
位取模。二元运算 predicate 取两输入 AND，常量运算沿用输入 0 predicate，
不使用常量 predicate。lane 数须为正并整除 `DATA_W`。

加法 helper 的 carry 高位、组合算术未用操作数／控制位／输出字段现在明确为零，
与原 PyMTL 二态模拟一致，避免综合把未驱动位当成任意值。没有使用 `setundef`
修改网表，也不声称保留原 HDL 的 X 传播行为。

`tile_vector_mul_combo` 原路由固定使用四个 lane；默认模式现明确要求 `LANES=4`，
仿真及综合参数检查均拒绝八 lane 配置。兼容模式允许四的倍数并保留高 lane 被
忽略的原缺陷，供固定 Python 轨迹对照。没有把这个兼容配置宣称为正确的八 lane 乘法。

乘法的既有 Python 数学契约继续保留：

- opcode 55 将四个完整的 `2*LANE_W` 位乘积按 `i*LANE_W` 偏移相加，再按
  `DATA_W` 取模；高乘积位可进入相邻 lane，**不是**各 lane 独立截断后拼接。
- opcode 75 为两个输入低 `2*LANE_W` 位的无符号乘积，高半字不参与。
- 以前修复的 Python→HDL 移位量截断保持修复；本兼容开关不会恢复该翻译缺陷。

两模块仍固定使用输入 0／1、输出 0，不使用 `fu_in` 动态选择；
`VECTOR_FACTOR_POWER` 沿用源模型忽略行为，组合 FU 入口仍要求该参数为零。
本项保持原无状态 reset／clear 和握手行为，包括乘法 `recv_opt.rdy` 直接跟随
输出 ready。复位／握手的后续统一审查见 `MIGRATION_TASKS.md` 第 9 项，
不能把本次数学检查当成该语义已经修复。

```sh
make -C sv current-vector-arithmetic current-vector-arithmetic-synth
```

六组未修改 Python 轨迹分别覆盖加法 32/1、32/4、64/8 和乘法 32/4、64/4、64/8，
每组 320 周期（包括 6 个 reset 采样）且比较完整输出。两项原始 Source/Sink
测试也原样运行。默认五组数学验收覆盖全部十个 opcode、全字溢出、借位、缺失
操作数、predicate、长背压和未用接口。兼容进位缺陷与八 lane 漏数据有独立失败见证。

原生／兼容共十一份综合网表逐一重新读入检查、验证零 SCC，并用相同台架运行；
错误数学预期必须失败。原有五组组合加法与三组 lane 加法 HDL 对照另行保留。
Base／Context／Streaming PE 各自通过公开配置包运行原生与兼容进位用例，
检查八周期输出背压、恰好一次输入／结果／完成及故意错误结果负控，验证参数向 FU 传递。
日志哈希和工具版本见 `reference/current/vector_arithmetic/validation.json`。
本项不声明八 lane 原生乘法、全系统综合网表、四态证明或 PPA 已完成。
