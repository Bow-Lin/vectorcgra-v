# 独立控制环与动态控制存储

`cgra_ring_multi_ctrl_mem` 对应 `mem/ctrl/RingMultiCtrlMemDynamicRTL.py`，
提供一个控制器报文入口、一个返回出口和每个 Tile 的控制字出口。
COLS×ROWS 个控制存储对应节点 0…NUM_TILES−1，控制器为节点 NUM_TILES。
COLS／ROWS 决定节点数与身份位宽，不在本模块中生成 PE 或二维数据网络。

实现复用现有 `cgra_credit_ring` 和 `ctrl_mem`。
`cgra_ring_ctrl_node` 只进行控制字字段的零填充／截取适配，不复制执行状态机。
它保留旧两输入控制字格式，也支持现有四输入格式及单输入格式；
原有 PE 和动态控制存储源码保持不变；共享环路由器和交换器改为逐端口静态连接／选择，
避免 sv2v 动态数组读写造成的综合膨胀，路由／无效消息语义保持原样。

## 参数和接口

| 参数 | 默认值 | 契约 |
|---|---:|---|
| COLS / ROWS | 2 / 2 | 正整数；环共有 COLS×ROWS+1 个节点 |
| DATA_W / DATA_ADDR_W | 32 / 7 | payload 数据／地址位宽；DATA_W≥11，地址位宽≥1 |
| CTRL_DEPTH / REG_DEPTH | 8 / 16 | 均≥2；后者只决定控制字内寄存器索引位宽 |
| NUM_CTRL / TOTAL_STEPS | 4 / 4 | 初始执行窗口长度／预算；1≤NUM_CTRL≤CTRL_DEPTH，0≤TOTAL_STEPS≤2047 |
| FU_INPUTS / FU_OUTPUTS | 4 / 2 | 当前适配范围为 1…4 输入、恰好 2 输出 |
| TILE_INPUTS / TILE_OUTPUTS | 4 / 4 | 各自为 1…8，可不对称；不表示实际实例化交叉开关 |
| LEGACY_PYTHON | 0 | 1 保留旧 dummy 返回源及未锁定返回选择；0 使用原生修正 |

不声称覆盖 Python 构造器能表示的任意 FU 数或任意 CtrlPktType。
本入口使用 `mk_intra_cgra_pkt(1,1,NUM_TILES,...)` 的单 CGRA 格式，
opaque 为 8 位、VC 为 1 位；CGRA 身份和坐标字段各 1 位。
控制字完整包含 operation、FU 输入选择、两类 crossbar 选择、vector factor、
is_last_ctrl 和四组寄存器字段，数组第 0 项位于各 packed 字段的低位。
编码在 `rtl/common/cgra_ring_ctrl_defs.svh` 和 `cgra_ring_ctrl_types.svh` 中定义。

- `recv_pkt_from_controller__{msg,val,rdy}`：控制器向环注入报文。
- `send_to_controller_pkt__{msg,val,rdy}`：控制器节点收到的报文。
- `send_ctrl__{msg,val,rdy}[0:NUM_TILES-1]`：逐节点独立控制字流。
- clk、同步高有效 reset。

控制器可向自身节点发送报文，完整消息会返回；不同 VC 之间不保证全局顺序。
环使用既有最短路径、平局向右和 dateline VC 规则，固定 2 VC／2 credit。
非法目的节点和控制存储配置地址在 RTL 仿真中报错；不是综合后的硬件错误响应。

## 执行和配置语义

CMD_CONFIG=3 写控制字，CMD_CONFIG_COUNT_PER_ITER=8 设置窗口长度，
CMD_CONFIG_CTRL_LOWER_BOUND=9 设置窗口首地址并立即移动 PC，
CMD_CONFIG_TOTAL_CTRL_COUNT=7 设置总预算。
先在停止状态下完成配置，再用 LAUNCH=0 或 RESUME=15 开始执行。
一条控制字仅在对应 `send_ctrl.val && rdy` 时退役，之后 PC 在窗口内循环。
FU prologue（命令 4）使相应槽位的前若干次输出 opcode 变为 NAH，
其余控制字段完整保留，prologue 也只在退役时减少。

预算为零表示无限循环；有限预算消耗完后，每节点注入一条 COMPLETE=14。
COMPLETE 的 src 为该节点、dst 为控制器，其余 payload 为零。
原生模式无功能单元，因此不包含 RET 数据或其它 FU 事件的返回能力。
当前字的 opcode=START 会停止控制字输出，但不会提前产生 COMPLETE。

保留的原动态存储规则：

- reset 清除执行状态、计数、prologue 和环中流量，**不清除控制字存储**。
  使用前应编程所有会访问的槽位；Python 和 Verilator 的零初值对照不构成 ASIC 上电保证。
- TERMINATE=2 清除执行次数并停止发出控制字，但保留 PC、程序及配置。
  LAUNCH／RESUME 本身不重置 PC 或执行次数；重新执行通常需要 TERMINATE、
  显式设置窗口首地址，再 LAUNCH／RESUME。
- 运行中写当前控制槽、移动窗口或发 TERMINATE 可以改变／撤销正在提供的控制字；
  此入口不增加运行中重配置的事务隔离。普通稳定性保证以停止后配置为前提。
- 动态窗口长度字段宽度沿用 `clog2(NUM_CTRL+1)`；配置值必须可表示，
  窗口长度必须非零，首地址+长度不能超过 CTRL_DEPTH。预算限于 11 位。
- PAUSE、PRESERVE、RECORD_PHI_ADDR、Streaming 配置等仍是基类接受的命令，
  本包装层没有 ContextSwitch／Streaming 执行能力，不把“接受”称为已实现对应功能。
- FU／routing crossbar prologue 可写入，但其输出未暴露；转发到 FU 的循环、GEP、
  全局归约响应等报文也没有消费者。这些 sideband 均未增加到原包装层接口。
- 存储配置命令接受表沿用 CtrlMemDynamicRTL。对 Tile 注入未支持的命令
  （例如 CMD_CONST=13）会阻塞该节点的接收队列，调用者不得这样配置。

## 原生修正与 Python 对照

原包装层将每个 `recv_from_element` 固定为 valid=1、全零 payload。
动态存储优先转发这个队列，持续返回 cmd=0 空报文，并使有限预算的 COMPLETE 饥饿。
原测试只检查每个节点的两条控制字，把控制器返回 ready 固定为 0，因此没有覆盖该问题。
本批直接运行未修改的 Python 复现了它，没有替换硬件参考或禁用原 Source/Sink 断言。

默认原生模式将不存在的 FU 返回源置为无效，有限执行可正常完成。
既有环的 VC 选择可能在背压期间轮换，所以原生返回口增加一个单项普通队列，
锁存已经选中的完整报文。它引入一个时钟的最低返回延迟，连续返回最大吞吐为每两拍一条。
它不改变其它环实例的仲裁规则。

`LEGACY_PYTHON=1` 同时恢复 dummy 事件源与直接返回连接，用于完整逐周期对照。
兼容模式仍有上述缺陷；不得把它通过对照解读为正确的完成／背压协议。

## 验证入口

```bash
make -C sv current-ring-ctrl-memory
make -C sv current-ring-ctrl-memory-synth
# 重新冻结参考才需要仓库指定的自定义 PyMTL：
python sv/migration_tools/current_ring_ctrl_memory.py --output-root /tmp/ring-reference
```

独立 HDL 构建使用 `filelists/ring_ctrl_memory.f`，日常仿真／综合不调用项目 Python。
四组参数为：

| 配置 | 节点阵列 | 数据位宽 | 控制深度 | FU 输入 | Tile 输入／输出 |
|---|---|---:|---:|---:|---|
| original | 2×2 | 16 | 16 | 2 | 4／4 |
| nonpower | 3×1 | 32 | 6 | 4 | 4／4 |
| wide | 1×2 | 64 | 8 | 4 | 8／8 |
| single | 1×1 | 32 | 3 | 1 | 3／5 |

兼容测试比较所有输出位，包括无效消息和 reset 周期；包含原测试及四组扩展轨迹。
原生检查包含完整控制字段、窗口、prologue、有限／无限执行、正常 COMPLETE、
终止与恢复、START、复位保留程序、两 VC 回环、credit 饱和和返回背压稳定性。
RTL 与实际综合网表使用同一测试台；错误 oracle、恢复旧 dummy 行为和非法配置必须被检出。
综合优化前后检查结构，并重新读入实际网表执行 `check -assert` 与 `scc -expect 0`。

本批证据单独存放于 `reference/current/ring_ctrl_memory/validation.json`，
日志在 `build/current/ring-ctrl-memory/`。该顶层尚未接入 PE／阵列；
本批结果不替代系统内核、Context/Streaming 或物理实现验收。
