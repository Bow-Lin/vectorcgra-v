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
