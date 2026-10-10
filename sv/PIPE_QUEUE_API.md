# 独立 PipeQueue API

`rtl/common/cgra_pipe_queue.sv` 对应 `lib/basic/val_rdy/queues.py::PipeQueueRTL`，
新增满队列同周期出入替换语义。已有 `cgra_queue` 的 Normal／Bypass 行为未改变，
本批没有替换 NoC、PE 或存储控制器内的队列。

参数：`DATA_BITS=35`（不透明完整消息）、`DEPTH=2`、`LEGACY_PYTHON=0`；
`COUNT_W=clog2(DEPTH+1)`、`ADDR_W=max(1,clog2(DEPTH))` 是派生宽度，不应覆盖。
DATA_BITS、DEPTH 至少为 1，非二次幂深度支持。

接口为 `recv__msg/val/rdy`、`send__msg/val/rdy`、`count`、clk、reset。
没有 clear 端口；使用 reset 清空队列。

- 数据路径为寄存路径，空队列不直通，输入最早在下一周期输出。
- 非满时可接收；已满但输出 ready=1 时，也允许同周期出队并接收替换元素。
  消费者读取旧队首，新元素入队尾，占用数保持不变；深度为 1 时同样成立。
- 连续出入可维持每拍一个元素。无出队时不能写满队列，不能溢出。
- 原生同步复位丢弃所有排队数据；reset 为高时 ready、val、count 和输出消息均为零。
  使用前必须提供复位时钟沿。正常空队列的输出消息也为零。
- 输出 valid 且背压时完整消息保持；生产者也须保持输入到握手完成。
- ready 组合依赖输出 ready，这是 PipeQueue 的固有契约；不隔断 ready 路径，
  不能把它当作避免组合环的隔离队列。

`LEGACY_PYTHON=1` 保留原队列复位周期的行为：reset 不屏蔽 ready/val，
占用数仅在时钟沿清零，写数据路径仍可能写入；无效输出为旧存储内容。
显式 initial 零值匹配 PyMTL 模拟初始状态，不承诺 ASIC 上电初始化。
两种模式都实现完整的 PipeQueue 替换语义；兼容开关并不是 Normal／Pipe 类型切换。

```bash
make -C sv current-pipe-queue current-pipe-queue-synth
python sv/migration_tools/current_pipe_queue.py --output-root /tmp/pipe-queue-reference
```

直接驱动未修改的项目 PipeQueue，冻结深度 1／2／3／5、8／35／67／19 位完整轨迹。
未发现这个项目包装层的独立原测试，不把 PyOCN 对其它队列实现的测试冒充为本 API 验收。
原生使用独立动态 FIFO 列表检查消息顺序、占用、守恒、复位丢弃、长背压及连续满替换，
RTL 和实际网表运行同一台架。用现有 Normal Queue 替代的负控必须在满替换检查失败，
兼容模式的复位假握手用例必须失败、原生必须通过；错误期望与非法派生宽度也须检出。
证据为 `reference/current/pipe_queue/validation.json`。
