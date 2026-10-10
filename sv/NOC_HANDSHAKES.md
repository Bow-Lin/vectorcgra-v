# NoC 仲裁、credit 与复位契约

原 PyOCN 的 SwitchUnitRTL 每周期推进仲裁，VC 出口也在 valid 而非实际
传输时推进。因此接收端阻塞时，已提供的消息可能被另一输入替换；即使
只停止优先级指针，新到达的高优先级请求仍可能改变选择。

原生 `cgra_switch` 现在在第一次阻塞时保存输入选择，保持至实际
`val && rdy` 传输，只有传输才推进 round-robin 优先级。输入生产者仍须
遵循 val/rdy 契约，在被接收前保持 valid 和消息。原生 credit 出口复用
该交换器，输入 VC FIFO 保留原来的深度及 bypass 行为。

credit 路由器先用发送器公开的只读 `available_credit` 筛选可发送候选，
再仲裁；该信号只依赖已寄存的 credit 计数和 reset，不从选中消息的
ready 反向形成组合反馈。筛选使用跨 dateline 改写后的 VC。

6 节点压力用例还暴露了 dateline 循环依赖：允许新包直接占用物理 VC1
时，可以形成一整圈 VC1 等待，而本地出口都有空闲 credit。原生 Ring
因此让新注入的合法 VC0／VC1 包都从物理 VC0 开始，增加一位内部旁带
保存原标签；跨 dateline 后使用物理 VC1，出口恢复“原标签或跨线 VC”。
外部消息位宽、字段和按原标签的交付顺序不变，注入端容量／时序变为
共享物理 VC0 的两个 credit。兼容模式保留原两类注入行为。

## 配置和兼容

独立 NoC 模块增加末尾参数 `LEGACY_PYTHON=0`，保留原参数的位置顺序。
设为 1 时保留原仲裁推进、invalid 消息、ready 和复位期间的可见行为。
系统公共参数 `NOC_LEGACY_PYTHON` 透传到 Mesh、Ring、控制环及交叉开关。

`MEMORY_LEGACY_PYTHON=1` 同时选择原存储控制器内部交叉开关的旧仲裁；
原生存储控制器也可通过 `NOC_LEGACY_PYTHON=1` 单独回退互连。独立
RingMultiCtrlMem API 使用其现有 `LEGACY_PYTHON` 选择对应控制环模式，
原生响应缓冲及其延迟保留。

Ring 仍要求两个 VC、每 VC 两个 credit，不扩展为任意 VC／credit 配置。
两位 VC 字段中的 2、3 在入口不被接受；跨 dateline 时依旧按原路由改写
VC。Ring 的 CHANNEL_LATENCY 仍沿用原模型未使用该参数的行为；Mesh
则保留实际的可配置链路队列。Mesh 单行／单列也仍不在当前支持范围。

## credit 和 reset

原生发送器在 credit 为零时停止发送；同拍发出和返还同一 VC 的 credit
时计数保持不变。接收器只在对应 VC 的消息被消费时返还一个 credit。
非法的入站 VC、无容量时收到入站包、额外 credit 导致计数溢出，都会在
RTL 仿真中报错。这些是协议违规诊断，不能把移除仿真断言后的综合网表
说成具有硬件错误恢复能力。

原生 reset 期间屏蔽发送、接收确认和返还 credit，复位后计数重新装满、
FIFO 与仲裁保持状态清空。必须共同复位网络端点与链路；协议没有 epoch，
不能靠单端复位识别来自旧任务的迟到 credit 或消息。无效周期的数据位
不构成有效传输，不能把它们当作已接收的包。

## 验收方式

```bash
make -C sv current-noc-handshakes
make -C sv current-noc-handshakes-synth
```

原语测试检查阻塞后新增请求、仅接收时推进的公平性、1／2／3／5 输入、
空闲及复位握手。credit 测试检查两个 VC 的满／空、按 VC 的顺序、逐拍
credit 守恒及身份、同拍发送／返还、带未完成流量的复位、非法 VC 拒收，
并包含原行为反例和协议违规断言负向测试。

网络测试分别运行原生和兼容模式：原生以独立包身份、内容、数量、顺序、
dateline 和阻塞保持为准；兼容模式 RTL 额外逐周期比较所有输出与冻结
PyOCN 参考，包括 invalid 数据位。综合网表仍逐拍比较 ready、valid
和所有 valid 消息（含阻塞周期）；未复位空队列的 invalid 数据位属于
未定义硬件状态，允许综合优化改变，差异数量单独记录。2×2 Mesh 的
严格 invalid 位网表对比在复位后的 cycle 28 失败，原始失败日志保留，
不把它计为完整 raw 等价通过。测试覆盖多个 Mesh／Ring 尺寸、32／64 位数据对应包宽和 Mesh
链路延迟，复位前刻意保留在途消息。选定的实际网络经过 sv2v、Yosys、
导出、重新读入 check／SCC，再执行相同公开接口测试。

完成的配置和计数以 `reference/current/noc_handshakes/validation.json`
为准：47 个正向运行、64 个预期失败检查、6 份实际网络网表。
集成检查包含存储控制器非对称端口／DMA、原生与兼容控制环、原始 NoC
逐位比较，以及多 CGRA Mesh／Ring 的独立数学结果和远程访存。
这些检查不宣称任意拓扑、无限流量或外部违反 val/rdy 契约时都
无死锁，也不代表所有 CGRA 系统配置的完整形式证明。
