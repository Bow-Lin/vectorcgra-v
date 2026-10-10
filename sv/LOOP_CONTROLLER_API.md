# 独立 LoopController 的接口与验收范围

M24 的 `rtl/controller/cgra_loop_controller.sv` 对应固定 Python 目标
`cd7aad878915` 的 `controller/LoopControllerRTL.py`。它是独立的 payload
组件；当前 `cgra_system` 和多 CGRA 系统没有实例化它。LoopCounter / LoopControl
FU 是另两个模块，不能代替此接口。

## 端口与参数

五个 val/rdy 接口分别为 `recv_config`、`recv_from_tile`、`recv_from_remote`、
`send_to_tile`、`send_to_remote`，另有 `clk`、同步高有效 `reset` 和
`all_loops_complete`。端口命名采用现有 SV 的 `__msg/__val/__rdy` 形式。

每个消息从高位到低位为：

```
cmd[6] | data.payload[DATA_W] | predicate[1] | bypass[1] | delay[1]
       | data_addr[DATA_ADDR_W] | ctrl[CTRL_BITS] | ctrl_addr[CTRL_ADDR_W]
```

`CTRL_BITS` 是不透明的控制字宽度，默认 107，对应原 LoopController 测试的
`mk_ctrl(4,2,4,2)`；当前四端口 PE 控制字可用 119。两者不能混接而不调整参数。
`NUM_CCUS` 默认 8，必须能由 `CTRL_ADDR_W` 寻址；`MAX_TARGETS` 默认 4，
范围 1…15，因为原配置/完成计数均为 4 位。其它数据字段沿用 `mk_data(DATA_W,1)`。
单 CCU 和单目标保留最少 1 位索引；控制地址和数据地址至少 1 位。

配置通过命令 32–37 设置下界、上界、步长、完成事件阈值、目标、父关系；
命令 38 启动所有有目标或标记为根的 CCU。配置字段和编码完全沿用 Python：

- `ctrl_addr` 是配置的 CCU 下标；目标配置的数据 payload 低位是目标控制地址。
- 目标配置的 `data.predicate` 选择远程输出，`data_addr` 最高位选择 shadow 模式。
- 父配置的 payload 低 `max(clog2(NUM_CCUS),1)` 位是父下标，紧接的一位是 root。
- 每次目标配置追加一个目标，直到 reset 清空写指针；LAUNCH 不清空配置。

原模型还保存目标 tile ID 和 CGRA ID，但从未读取，且输出接口没有路由头。
SV 不保留这些不可观察寄存器，也没有新造目的 ID 端口。远程输出仅表示
选择 `send_to_remote`，不表示已经完成 NoC 目的路由集成。

## 保留的 Python 行为

- LAUNCH 进入 RUNNING，从下界开始，不主动发送第一轮 reset/shadow。
- 本地 `CMD_LEAF_COUNTER_COMPLETE=31` 只按目标 `ctrl_addr` 匹配运行中的
  本地、非 shadow 目标；不检查来源 tile ID。一个事件可能匹配多个 CCU。
- 远程 `CMD_LC_CHILD_COMPLETE=40` 会通知全部 RUNNING CCU，不按来源或目标地址区分。
  没有运行中 CCU 时不消费该事件；其它事件命令被消费但不执行操作。
- 完成次数达到阈值后，以 DATA_W 位无符号加法更新值，predicate 置 1，
  bypass/delay 清零。新值达到上界时直接 COMPLETE，不派发多余的终止消息。
- 非终止轮次按目标顺序发送 `RESET_LEAF_COUNTER=27` 或
  `UPDATE_COUNTER_SHADOW_VALUE=26`。后者携带当前值，前者的数据为零。
  两个输出共享最低 CCU 下标优先的派发器，只在选中输出握手时推进。
  仲裁没有锁定：低编号 CCU 新进入派发状态时，可以抢占正在背压的高编号输出；
  集成时还需约束事件时序或另行修正仲裁，不能据本批静态背压测试推断任意并发下消息稳定。
  原 Python 的最小实验已复现：两个 root 分别接收地址 1、0 的完成事件，输出始终
  `val=1/rdy=0`，待发消息的 ctrl_addr 却从 1 变成 0。
- 完成全部目标派发后，清零完成计数，并复位直接子 CCU 的运行状态和当前值。
  原 Python 也会复位尚未配置但 parent 默认指向该 CCU 的条目，此行为保留。
- 本地叶事件令一个非 root CCU 完成时，会更新其直接父 CCU；通知不递归传播到祖父。
  远程完成路径没有同样的父通知操作。
- 同一时钟沿对同一寄存器的更新保留 Python 的最后赋值优先：配置、派发、
  本地事件（按 CCU/目标顺序）、远程事件。右值均来自时钟沿前的状态，
  因此两个同时到来的完成不保证累加两次；重复完成也没有按子节点去重。
- `all_loops_complete` 只检查 root，root 为 IDLE 或 COMPLETE 均算完成。
  非 root 仍在工作、或尚未配置任何 root 时，它也可能为 1。

因此本 API **不是任意 DAG、并发完成无损收集或任意跨 LC 链的验收**。
调用者仍需遵守原测试的配置和事件调度约束；动态改配、重复事件、零步长、
降序/空循环和无目标的非终止循环没有新增语义保证。配置之外的并发事件、
优先级以及部分限制有冻结轨迹，匹配原行为不代表这些限制已修复。

## 原生边界修正

原 Python 用 `clog2(MAX_TARGETS)` 位计算下一个派发索引，再与 4 位目标数比较。
当目标数填满 4 或 8 个槽时，最后一个索引加一先回绕成零，派发无法结束。

默认 `LEGACY_DISPATCH_WRAP=0` 先用 4 位计算下一位置并判断结束，再缩窄存储索引。
`LEGACY_DISPATCH_WRAP=1` 仅用于复核原 Python 的回绕行为。该参数不改变其它事件语义。

越界 CCU、目标写满后继续追加、非法父下标会在 RTL 仿真时报错；这些输入在 Python
中没有稳定定义（可能在后续数组访问时报错）。检查不作为综合后的硬件错误响应接口。

## 验证入口

```
make -C sv current-loop-controller
make -C sv current-loop-controller-synth
```

日常入口只使用 SV/Verilog 与冻结文本，不调用项目 Python。
`migration_tools/current_loop_controller.py` 是单独的参考生成工具；先核对原项目
274 个 Python SHA，然后调用未修改的 Python。可用 `--output-root` 在独立目录重现。

| 配置 | DATA_W | NUM_CCUS | MAX_TARGETS | CTRL_BITS | CTRL_ADDR_W | Python 轨迹周期 |
|---|---:|---:|---:|---:|---:|---:|
| default | 32 | 8 | 4 | 107 | 3 | 611 |
| wide | 64 | 3 | 3 | 119 | 3 | 482 |
| single | 32 | 1 | 1 | 119 | 1 | 465 |
| eight_targets | 32 | 8 | 8 | 119 | 4 | 522 |

合计 2080 个采样周期，其中 12 个场景复位周期只施加复位、不比较复位前的状态；
其余 2068 周期比较全部顶层输出位，包括无效消息。default 包含原 Python 的
四个测试：两层循环、兄弟屏障、三层循环及远程循环，原 Sink 断言继续执行。
补充轨迹包含并发事件、广播、重新启动、背压、目标填满和非二次幂参数。

原生测试独立检查屏障次数、32/64 位 shadow 数值、目标恰好派发一次、
无终止派发、父子重启、最低索引仲裁、输出背压、relaunch 和中途 reset。
同一个测试平台运行 RTL 和 sv2v/Yosys 实际综合网表，综合优化前后均执行
`check -assert`。故意错误期望、恢复旧回绕及非法配置必须失败。

具体执行状态、日志摘要、代码/参考/网表 SHA 见
`reference/current/loop_controller/validation.json`。这是 M24 的独立模块验收；
此前 M23 的全系统记录未被此结果替代。
