# 独立 LoopController 的接口与契约

`rtl/controller/cgra_loop_controller.sv` 是独立 payload API，默认使用修正后的
`cgra_loop_controller_native`。`LEGACY_PYTHON=1` 选择固定 Python 目标
`cd7aad878915` 的兼容核心；同时设 `LEGACY_DISPATCH_WRAP=1` 可完整复现其
满目标槽索引回绕。只设兼容模式、保持 wrap=0 时仅修复索引回绕。

当前 `cgra_system` 和多 CGRA 系统**没有实例化** LoopController。LoopCounter／
LoopControl FU 是不同模块；这里没有增加 NoC 目的路由或系统集成。

## 消息与参数

五个 val/rdy 接口为 `recv_config`、`recv_from_tile`、`recv_from_remote`、
`send_to_tile`、`send_to_remote`，另有同步高有效 `reset` 和 `all_loops_complete`。
消息从高位到低位：

```
cmd[6] | data.payload[DATA_W] | predicate | bypass | delay
       | data_addr[DATA_ADDR_W] | ctrl[CTRL_BITS] | ctrl_addr[CTRL_ADDR_W]
```

`CTRL_BITS` 是不透明控制字宽度，默认 107；当前四端口 PE 可用 119。默认
`NUM_CCUS=8`、`MAX_TARGETS=4`；CCU 数须可由 `CTRL_ADDR_W` 寻址，目标数为
1…15（4 位计数）。数据位宽至少 4，且大于 CCU 索引宽度、不小于控制地址宽度；
其余字段至少一位。单 CCU／单目标索引仍用一位。

| 命令 | 配置意义 |
|---|---|
| 32／33／34 | 下界／上界／正步长，取 `data.payload` |
| 35 | 每轮完成阈值，取 payload 低四位，合法范围 1…15 |
| 36 | 追加目标：payload 低位为目标控制地址，predicate 选择远端，data_addr 最高位选择 shadow |
| 37 | parent：payload 低 `max(clog2(NUM_CCUS),1)` 位为父 CCU，下一个位为 root |
| 38 | 启动全部已配置 CCU，或完成后保留配置重新启动 |

32–37 的 `ctrl_addr` 是配置 CCU 下标。目标追加指针仅 reset 清空；不能在填满后
继续追加。原模型的目标 tile／CGRA ID 从不参与输出且接口无路由头，SV 没有把这些
无效字段包装成可用路由能力。

## 默认模式

配置为有根、无环的**森林**：每个非 root 恰有一个本地父节点，父节点必须已配置。
任一配置命令将 CCU 标为已配置，支持没有输出目标的中间父节点。
本批定义并验收正步长、`lower < upper` 的升序循环；零步长、空循环、降序循环
及无根／循环 parent 关系在 RTL 仿真中明确拒绝，不声明任意 DAG 支持。

- 未启动时 `all_loops_complete=0`。启动后，全部已配置 CCU 都为 COMPLETE 才置 1；
  保持到下一次被接受的重新配置、启动或 reset。没有配置 root 不能用“空集合为真”伪装完成。
- 启动进入 RUNNING，从下界开始，不主动发送初始 reset/shadow。配置仅在首次启动前
  或全部完成后接受；运行、派发和背压期间配置 ready 为零，发送方须保持请求。
- 本地命令 31 根据目标控制地址匹配正在运行的本地、非 shadow 目标，每个匹配
  CCU 对一个输入消息计一次完成；重复配置同地址目标不将一次消息放大多次。
  接口没有来源 tile ID，可能匹配多个 CCU；若期望唯一消费者，映射须确保地址唯一。
- **远程命令 40 的 `ctrl_addr` 是接收 CCU 下标**，仅给该 CCU 增加一次完成。
  这是显式原生契约变更：兼容模式仍复现 Python 向所有 RUNNING CCU 广播的行为。
  此 payload 地址不等于已实现跨控制器／NoC 的路由头。
- 本地与远程同拍握手、多个孩子同拍完成，都累加到同一完成计数，随后统一推进。
  每个 CCU 每拍至多前进一步，非终止派发保留已接收的剩余完成额度。父通知同样
  累加，并经寄存器在本地森林中逐拍向祖先传递，适用于本地或远程触发的孩子完成。
- 使用扩展一位的无符号加法判断是否越过上界，避免步长加法回绕导致不结束。
  达到上界即 COMPLETE，不发多余终止派发；未达到则按目标顺序派发本轮值。
- 非 shadow 输出命令 27（数据为零），shadow 输出命令 26（当前值、predicate=1、
  bypass/delay=0）。最低 CCU 下标优先；一旦消息受背压，锁定该 CCU 到该消息握手，
  后来的低编号请求不能替换已呈现消息。两个输出共享此派发器。
- 最后一个目标握手后重启整个已配置子树；没有目标的中间父节点也能重启子树。
  不再启动未配置但 parent 默认是零的条目。最后目标握手导致子树重启的同拍，其输入完成被背压，
  避免刚接收的旧事件在重置子树时消失。
- reset 屏蔽配置／完成 ready、派发 valid 和完成标志，同时清除配置、计数及锁定。
  未使用消息字段和未激活输出明确为零。

事件仍是**计数型协议**，没有来源身份、去重位或 epoch 标签。发送方必须限制实际
完成次数与配置阈值及循环次数一致；重复／多余终止完成在 RTL 仿真中报错，不能
把已接收的错误事件解释为成功去重。非法配置检查不是综合网表的硬件错误响应端口；
综合系统的配置生成方必须满足这些前提。

## Python 兼容模式

兼容核心保留源模型全部原行为：动态配置最后赋值优先、低编号抢占背压输出、
同拍完成覆盖、远程广播、仅本地叶完成通知一层父节点、根 IDLE 视为完成、
无 root 时完成为真、未配置默认 parent 条目也被重启。兼容模式的 reset 握手也保持
原样。它用于对照和诊断，不提供默认模式的新契约保证。

原 `reference/current/loop_controller/validation.json` 是此前独立 API 的历史证据，
未被改写。新结果位于 `reference/current/loop_controller_semantics/validation.json`。
原 Python 和四组冻结轨迹保持不变。

## 验证

```sh
make -C sv current-loop-controller current-loop-controller-synth
```

| 配置 | DATA_W | CCU 数 | 目标容量 | CTRL_BITS | CTRL_ADDR_W |
|---|---:|---:|---:|---:|---:|
| default | 32 | 8 | 4 | 107 | 3 |
| wide | 64 | 3 | 3 | 119 | 3 |
| single | 32 | 1 | 1 | 119 | 1 |
| eight_targets | 32 | 8 | 8 | 119 | 4 |

兼容检查沿用原 2,080 周期，12 个场景 reset 采样只施加输入，其余 2,068 周期
比较全部输出（包括 invalid 消息）。原四个 Python Source/Sink 测试在重新生成时
继续执行断言；生成到独立目录后逐字节核对冻结资产并检查原 274 文件哈希。

默认模式的独立测试覆盖目标填满、32／64 位值、并发叶／远程完成、兄弟完成相加、
祖先递归通知、三层循环八次叶完成、子树重启、地址选择、跨派发保留完成额度、
长背压和抢占、运行期配置背压、加法越界、重复启动及 reset。八项缺陷用例要求
默认模式通过而兼容模式明确失败；错误预期及非法配置同样必须失败。

原生／兼容各四份实际综合网表重新读取检查，验证零 SCC，并运行相同功能台架。
本工具链综合禁用可选的 SAT resource-sharing pass（`-noshare`）：该阶段在初次
森林调度综合中资源失控。其余结构优化、`check -assert`、实际网表 SCC 和完整功能
检查保留，不使用 undef 补值，也不据此作面积最优性声明。
这不是四态／所有程序的形式证明，也不代表已完成 LoopController 系统路由、
全系统回归、FPGA／ASIC PPA 或远端 CI。
