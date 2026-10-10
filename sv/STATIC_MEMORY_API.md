# 独立静态控制存储与常量 ROM

`cgra_static_ctrl_mem` 对应旧 `mem/ctrl/CtrlMemRTL.py`，
`cgra_static_const_queue` 对应旧 `mem/const/ConstQueueRTL.py`。
两者进入 `filelists/native.f`，尚未实例化到 PE／阵列；PE 的动态配置存储、
按控制步退役的常量队列继续使用原有模块。

默认 `LEGACY_PYTHON=0` 使用下面的原生契约。
`LEGACY_PYTHON=1` 仅用于复核冻结的历史行为。

## 控制存储

参数：`CTRL_BITS=119`、`DEPTH=8`、`COUNT_PER_ITER=4`、`TOTAL_STEPS=4`，
`OP_LSB=CTRL_BITS-7` 指定 7 位 opcode 的最低位。
其余控制位作为不透明消息完整保存；旧 `.ctrl` 与当前 `.operation`
字段名不影响 SV 的位编码。`ADDR_W=max(1,clog2(DEPTH))` 为派生宽度，不应覆盖。
合法原生范围：`DEPTH>=1`、`1<=COUNT_PER_ITER<=DEPTH`、`TOTAL_STEPS>=0`，
opcode 位域必须位于消息内。

端口均为普通 val/rdy：`recv_waddr__{msg,val,rdy}` 接收地址，
`recv_ctrl__{msg,val,rdy}` 接收控制字，`send_ctrl__{msg,val,rdy}` 输出当前字。

| 行为 | 默认原生模式 | Python 兼容模式 |
|---|---|---|
| 配置写入 | 地址和数据同拍握手才写；单独到达的半边不握手 | 两个 ready 恒为 1，但仅两个 valid 同时为 1 才写，可能丢失半边 |
| 执行预算 | 只在输出 `val && rdy` 时消耗一次 | 当前 opcode 非 START 的每个周期都消耗，包括背压 |
| PC 前进 | 只在输出握手时前进，周期为 COUNT_PER_ITER | 当前 opcode 非 START 且 ready 时前进，预算耗尽后仍前进 |
| START（opcode=0） | 当前字无效，PC 停止；可配置该字使其继续 | 同左 |
| 运行中改写 | 背压中的有效当前字不可改；其它地址可以写；当前字被接收当拍可以替换 | 不保护当前字，可能破坏背压稳定性 |
| 复位 | 同步高有效：清空程序、PC 和预算；复位期间所有握手被屏蔽 | 忽略 reset，写入和前进仍可能发生 |
| `TOTAL_STEPS=0` | 无上限循环 | 原 Python 在构造 Bits0 时失败，因此 SV 兼容模式拒绝 |
| `DEPTH=1` | 支持单槽位 | 原 Python Bits0 失败，因此兼容模式拒绝 |

原生配置口没有缓存：生产者必须独立于 ready 发出 valid，保持消息与 valid，
直到两端同拍握手。ready 会组合依赖另一端 valid，以及当前指令的消费情况。
上游不能等待 ready 才产生 valid。非法地址不握手，并在 RTL 仿真中报错。

没有 launch 端口。复位后的全零字为 START；加载程序时先写其它地址，最后写地址 0。
读为组合读、写在时钟上升沿提交；同拍读写当前地址时消费者接收旧值。
每轮只执行前 COUNT_PER_ITER 个槽位，其余地址可存储但不会被 PC 访问。
预算耗尽后没有独立 restart 命令；原生复位后需重新加载程序。

## 常量 ROM

参数为 `DATA_BITS=35`、`NUM_CONST=3`、`CONST_WORDS`、`LEGACY_PYTHON=0`。
`DATA_BITS` 是完整消息宽度；当前 `mk_data(W,1)` 为 W+3 位，低三位依次为
predicate、bypass、delay。`CONST_WORDS[i*DATA_BITS +: DATA_BITS]` 为第 i 项。
默认 ROM 内容为零；使用者应在实例化时提供实际常量。

端口为 `send_const__{msg,val,rdy}`、clk、reset，没有动态写口。
每次有效输出握手前进一项，末项回到第 0 项；背压期间完整消息保持稳定。
原生同步复位将指针归零且不改变常量，reset 为高时 val=0。
reset 上升但时钟尚未到来时 msg 仍可以是旧项，不能在 val=0 时当作传输。
`NUM_CONST=0` 在原生模式中输出 msg=0、val=0，参数位宽保留一个占位项。
单项、非二次幂项数均支持。常量按这个独立接口的握手前进，
不使用 PE 动态常量队列的 `ctrl_proceed` 退役规则。

兼容模式忽略 reset，非空时 val 恒为 1，ready 为 1 即前进；
空表在原 Python 中不能构造，因此 SV 兼容模式显式拒绝。

## 历史对照的边界

原 Python 两个模块和 RegisterFile 都没有 reset 分支，但 PyMTL 仿真默认零初始化。
兼容 SV 以 `initial` 零初始化存储／指针／计数器，保留忽略运行中 reset 的行为。
这用于仿真及支持寄存器初始化的目标；通过通用综合与网表仿真不意味着 ASIC
上电状态有保证。默认原生模式使用真实同步复位，使用前必须复位。

旧 CtrlMem 读取 `.ctrl`，直接传入当前 `mk_ctrl` 会报 `VarNotDeclaredError`。
冻结工具仅创建一个同位布局的消息类型，将 `.operation` 字段名改为 `.ctrl`，
再运行未修改的 CtrlMem；没有修改原 Python 或掩盖原接口失败。
depth=8／period=2 可以在当前自定义 PyMTL 中执行；不能仅凭 zext 的名字推断它失败。
原 ConstQueue 的现有测试原样通过；废弃 CtrlMem 测试的旧构造接口没有被冒充为通过。
相关证据见 `reference/current/static_memory/python_boundaries.json`。

## 验证与复现

```bash
make -C sv current-static-memory
make -C sv current-static-memory-synth
# 仅重新冻结参考时需要仓库指定的自定义 PyMTL 环境：
python sv/migration_tools/current_static_memory.py --output-root /tmp/static-reference
```

兼容对照包含 3 组 CtrlMem 和 4 组 ConstQueue，所有周期、所有输出位均比较，
包括无效消息和 reset 周期。原生测试覆盖控制深度 1／3／4／8、周期小于深度、
107／119 位控制字、自定义 opcode 位置、有限及无限预算，
以及 16／32／64 位常量 payload 和空表／单项／3／4 项 ROM。
RTL 与真实 sv2v→Yosys 网表使用同一台架；综合优化前后均运行 `check -assert`。
Verilator 对生成网表的位别名／拼接产生 `UNOPTFLAT` 告警；重新读入全部 18 份
实际网表后，`check -assert` 与 `scc -expect 0` 均通过，未发现位级组合环。
回归保留告警并执行这项检查，没有通过屏蔽告警来声明结构正确。

错误期望必须失败；旧预算、丢失半边写入、CtrlMem 复位及 ConstQueue 复位缺陷
分别在兼容模式失败，并在原生模式通过。参数／地址报错是 RTL 仿真断言，
不声称综合后的硬件提供错误响应。
本批详细结果及 SHA 在 `reference/current/static_memory/validation.json`；
日志在 `build/current/static-memory/`。本批不重跑系统内核，不声称新的系统集成或 PPA 验收。
