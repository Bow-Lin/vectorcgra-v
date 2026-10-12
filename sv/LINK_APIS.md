# 独立组合链接 API

## N 输入 OrLink

`rtl/noc/cgra_or_link.sv` 对应 `noc/OrLinkRTL.py`，与已有的双来源
`tile_link_or` 是不同接口，未替换 PE 内部实例。
参数 `DATA_W=32`、`NUM_INPUTS=3`；二者至少为 1。
消息布局固定为 `{payload[DATA_W-1:0], predicate, bypass, delay}`，
不承诺其它 predicate／bypass 位宽。

端口为 `recv__msg[0:NUM_INPUTS-1]`、按输入编号索引的 `recv__val/recv__rdy`，
以及 `send__msg/val/rdy`、clk、reset。

- 输出 valid 是所有输入 valid 的 OR。
- 只要任一 valid 为 1，输出 payload 与 predicate 就分别是**所有输入**对应字段的 OR，
  包括 valid=0 的输入。没有 valid 掩码，也没有优先级仲裁。
- 所有输入 valid=0 时，输出消息为零；bypass 与 delay 始终为零。
- 每个输入 ready 都直接等于输出 ready，与本口 valid 无关。
- 纯组合、无存储、无新增延迟；clk/reset 不改变结果，复位时仍遵循上述组合公式。
  若需要背压期间输出保持，上游必须保持所有参与 OR 的字段，包含无效输入字段。
  这不是可任意拼接独立异步流的合并队列。

原 Python 声明了未使用的 `mk_bits(clog2(NUM_INPUTS))`，导致单输入构造失败；
原生 SV 支持单输入退化情况，但仍清除 bypass/delay 并在无效时输出零。
本 API 没有默默将 OrLink 改为按 valid 选路器。

```bash
make -C sv current-or-link current-or-link-synth
# 仅重新冻结参考需要自定义 PyMTL：
python sv/migration_tools/current_or_link.py --output-root /tmp/or-link-reference
```

原有 Python Source/Sink 测试原样运行；3／5／8 输入、16／32／64 位 payload
另有完整端口轨迹，包含 reset 和 invalid 消息。独立位计数检查穷举每组参数的
全部 valid 组合、两个 ready 值及两个 reset 值，另外覆盖 1 位／单输入。
相同检查与错误期望负控用于 RTL 和实际 sv2v→Yosys 网表；优化前后检查结构，
并重新读入输出网表检查零位级组合环。证据见 `reference/current/or_link/validation.json`。

## Selector

`rtl/noc/cgra_selector.sv` 对应 `noc/SelectorRTL.py`。
参数 `DATA_BITS=35`（不透明完整消息）、`NUM_INPUTS=3`、`LEGACY_PYTHON=0`，
`SEL_W=max(1,clog2(NUM_INPUTS))` 为派生宽度，不应覆盖。
所有宽度、端口数至少为 1。接口同 OrLink，但增加 `recv_from` 选择输入编号，
消息宽度使用 DATA_BITS，不解释 payload 或 metadata。

默认原生模式组合输出所选输入的完整 msg 与 val，无效消息也原样传递。
只有所选输入的 ready 等于 send ready，其余 ready 始终为零。
clk/reset 不参与这个无状态路由；选择信号和选中输入须保持到握手完成。
本模块不锁定外部选择、不提供队列或仲裁功能，不把任意改变选择信号视为合法背压协议。
非法选择值在 RTL 时钟沿诊断（reset 期间除外）；组合输出为零、所有 ready 为零，
不承诺硬件错误响应。

`LEGACY_PYTHON=1` 保留原 Python 的缺省赋值遗漏：只更新当前选择口的 ready，
未选口保留历史值，因此存在 ready 锁存器和误消费风险；reset 也不清除该值。
兼容模式以 initial 零值匹配 PyMTL 的模拟初始状态，不是 ASIC 上电保证。
原 Python 单输入因 Bits0 失败，兼容模式显式拒绝；原生支持单输入。

```bash
make -C sv current-selector current-selector-synth
python sv/migration_tools/current_selector.py --output-root /tmp/selector-reference
```

原 Selector 的固定选择 Source/Sink 测试原样运行，另外冻结不断切换选择口的
未修改 Python 轨迹，直接观察未选 ready 保持。19／35／67 位、3／5／8 输入覆盖全部
输出位，包含无效消息和复位；原生加 8 位／单输入，穷举选择口、valid 掩码、ready、reset。
同一个残留 ready 用例必须在兼容模式失败、原生模式通过。
RTL 和实际网表使用同一台架；证据为 `reference/current/selector/validation.json`。
