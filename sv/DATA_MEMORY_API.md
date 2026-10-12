# 独立数据存储 API

`rtl/mem/cgra_data_mem.sv` 对应 `mem/data/DataMemRTL.py`，是独立多端口存储。
它不替换 PE／阵列已使用的 `cgra_data_bank` 或 `cgra_data_memory` 控制器。

参数为 `DATA_BITS=35`（完整消息，包括所有元数据）、`DEPTH=16`、
`RD_PORTS=1`、`WR_PORTS=1`、`PRELOAD_ENABLE=0`、`PRELOAD_WORDS='0`、
`LEGACY_PYTHON=0`。所有宽度、深度及端口数至少为 1；
`ADDR_W=max(1,clog2(DEPTH))` 是派生参数，不应覆盖。
`PRELOAD_WORDS[i*DATA_BITS +: DATA_BITS]` 是地址 i 的复位映像。
没有文件加载、字节使能或运行时配置口，所有地址均为字地址。

每个读口有 `recv_raddr__{msg,val,rdy}` 和 `send_rdata__{msg,val,rdy}`；
每个写口有 `recv_waddr__{msg,val,rdy}` 和 `recv_wdata__{msg,val,rdy}`。
消息为 unpacked 数组，val/rdy 为按端口编号索引的 packed 位向量。

## 默认原生契约

- 组合读，无背压时不新增延迟；同拍读写同一地址时读取旧值。
- 地址和写数据必须同拍有效才握手，未成对的半边不接收、不丢弃。
  生产者独立于 ready 产生 valid，并保持到握手。写口没有输入缓存。
- 同周期写同一地址，较大写端口编号获胜；所有成对写仍完成握手。
- 读请求背压时，在第一个时钟沿保存完整结果；后续写入不改变该结果。
  写入无需等待读端，写 ready 不依赖读 ready。
  读地址生产者同样须保持地址和 valid 直到握手。
- 预加载是未写位置的只读映像，读操作没有写入副作用；第一次合法写直接覆盖映像。
  未启用预加载时，未写位置逻辑值为零。
- 同步高有效复位清除写入标记和滞留读结果，恢复逻辑映像；RAM 本体不必清零。
  reset 为高时屏蔽所有握手，读消息为零；首次使用前必须复位。
- 无效读消息为零。非二次幂深度支持；非法有效地址在 RTL 仿真报错，
  不承诺综合硬件对非法地址提供响应。单词深度支持，地址宽度为 1。

## Python 对照模式

`LEGACY_PYTHON=1` 保留原模型的以下行为，供迁移取证使用：

| 行为 | 未修改 Python / 兼容 SV |
|---|---|
| 写 ready | 地址与数据恒为 1，分离到达可能丢失 |
| 预加载 | 未初始化读地址每拍触发内部写，即使读 valid=0；其优先级高于外部写 |
| 初始化标记 | 读 valid 或写地址 valid 即置位，不要求握手／有效写数据 |
| 预加载模式写控制 | 写地址 valid=0 时保留旧地址、数据及使能，可能持续旧写 |
| 背压读 | 不保存结果，可能被写入改变 |
| reset | 忽略，复位期间仍可读写 |
| 上电状态 | 用 initial 零初始化模拟 PyMTL；不是 ASIC 上电保证 |

兼容模式有意保留源模型的写口锁存器，默认原生分支不含该锁存器。
原 Python 的单词深度构造失败（Bits0），SV 兼容模式同样拒绝。
预加载参数是完整位向量；调用者应显式补齐未提供的映像项，
不要依赖原 Python 短预加载列表的未驱动值。

## 验证

```bash
make -C sv current-data-memory
make -C sv current-data-memory-synth
# 只有重新取证才依赖自定义 PyMTL 环境：
python sv/migration_tools/current_data_memory.py --output-root /tmp/data-memory-reference
```

原有 DataMem 测试保留 Source/Sink 断言；另对 3 读／2 写预加载、
2 读／3 写无预加载记录全部端口位，包括无效消息与复位周期。
默认模式用独立存储计分板检查冲突优先级、同拍读写、全部元数据、
长背压期间持续改写、地址／数据分离、多次复位、全地址回读及单词深度。
预加载覆盖、丢失半边写、背压变化及忽略复位四项缺陷必须在兼容模式失败，
在原生模式通过。错误预期负控必须失败。

相同测试用于 RTL 和 sv2v→Yosys 实际输出网表。综合前后及重新读入网表均运行
`check -assert`；综合后及实际网表均检查 `scc -expect 0`。
详见 `reference/current/data_memory/validation.json`，日志在
`build/current/data-memory/`。不以组件验收代替系统内核回归或 PPA 验证。

## DataMemScalable API

`rtl/mem/cgra_data_mem_scalable.sv` 对应 `DataMemScalableRTL.py`，
参数与本地读写接口完全相同，实例化上面的核心，不复制存储状态机。
它增加 `recv_from_noc__{msg,val,rdy}`、`send_to_noc__{msg,val,rdy}`，
消息宽度同为 DATA_BITS。

原 Python 将三个 NoC 输出固定为零，尚无 miss／远程访存实现。
本包装层在原生／兼容模式、正常运行／reset 时都保持：
`recv_from_noc__rdy=0`、`send_to_noc__val=0`、`send_to_noc__msg=0`。
NoC 输入任意变化不影响本地读写。无效本地地址仍按本地 API 边界报错，
不会转换为远程请求。名称中的 scalable 不代表已支持真实多 CGRA 远程访存。

```bash
make -C sv current-scalable-memory current-scalable-memory-synth
python sv/migration_tools/current_data_memory_scalable.py --output-root /tmp/scalable-reference
```

此 API 有独立的未修改 Python 轨迹，记录所有本地与 NoC 输入／输出位；
原有 Scalable 测试保留 Source/Sink 断言。原生计分板同时切换 NoC 输入和 ready，
逐拍检查三个 NoC 输出固定为零，并验证本地结果、背压和复位。
证据为 `reference/current/data_memory_scalable/validation.json`。
