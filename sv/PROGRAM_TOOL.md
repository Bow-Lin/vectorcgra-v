# 独立程序与消息打包工具

`tools/cgra_program.py` 把显式控制字、常量、预加载和命令序列打包为
当前 SV 主机接口文件。运行只需 Python 标准库以及同目录的
`cgra_config.py`、`abi.json`，不需要项目 Python、PyMTL 或 migration_tools。
已映射的标量 ReLU YAML 可通过单独的 [YAML 前端](YAML_RELU.md) 进入此打包流程；
该可选前端需要 PyYAML，支持范围独立列出。

```bash
python3 -I -S sv/tools/cgra_program.py \
  --config sv/examples/config/heterogeneous.json \
  --program sv/examples/program/heterogeneous.json \
  --output work/my-program
```

`--config` 使用 [架构配置工具](CONFIGURATION_TOOL.md) 的 JSON 输入。
`--check` 只校验；实际输出要求目录尚不存在，不会覆盖已有程序。
控制字位宽和数组长度来自同一架构配置，数组元素 0 位于该字段低位。

## 有序步骤

```json
{
  "schema": 1,
  "control_defaults": {"fu_in": [1, 2, 3, 4]},
  "steps": [
    {"kind": "preload", "address": 15, "values": [7, "0xdeadbeef"]},
    {"kind": "constants", "cgra": 0, "tile": 0, "values": [15, 16]},
    {"kind": "program", "cgra": 0, "tile": 0, "words": [
      {"operation": "LD_CONST", "fu_xbar_outport": {"3": 1}},
      {"operation": "STR_CONST", "routing_xbar_outport": {"4": 1}}
    ]},
    {"kind": "command", "cmd": "LAUNCH", "cgra": 0, "tile": 0},
    {"kind": "barrier", "completions": 1},
    {"kind": "command", "cmd": "LOAD_REQUEST", "data_addr": 16}
  ]
}
```

该片段展示语法；路由连接的其他 Tile 程序由调用者提供。可运行的完整
21 PE 示例是 `examples/program/heterogeneous.json`，与对应架构配套。
工具保持步骤顺序，不推导数据流映射或安排跨 Tile 调度。

| `kind` | 展开行为 |
|---|---|
| `preload` | 从 `address` 开始按全局**字地址**递增，发送 `STORE_REQUEST` |
| `constants` | 向指定 Tile 按原顺序发送 `CONST` |
| `program` | 配置迭代长度、总步数，然后依次发送 `CONFIG` 控制字 |
| `command` | 发送一个具名命令，可指定 `data`、`data_addr`、`ctrl`、`ctrl_addr` |
| `packet` | `packet` 字段直接提供完整 host 结构体字段 |
| `barrier` | 在当前位置等待累计 `completions` 个完成事件；不产生硬件命令 |

`cgra` 和 `tile` 默认 0。`program` 的 `period`、`total_steps` 默认
为控制字数量；`start` 默认为 0。非零入口只允许 Context，其程序步骤
会显式发送 `CONFIG_CTRL_LOWER_BOUND`，包括重配回 0 的情况。
Base／Streaming 的入口仍为 0；可用底层 `CONFIG` 命令单独写指定地址。

`control_defaults` 在控制字字段一级合并；控制字中明确提供的数组会
替换默认数组。数组可用完整列表，或以十进制下标字符串为键的稀疏对象；
未指定元素为零。`fu_in` 选择范围为 0…4，FU crossbar 选择为 0…2，
路由选择和寄存器索引必须落在配置范围。Streaming 不允许配置没有连接
的寄存器到 routing 路径。

`preload`／`constants` 的数字值默认打包为 `data_t`，predicate=1、
bypass=delay=0；也可显式给出 `{"payload":7,"predicate":0}` 等字段。
`command.data` 的数字值默认 predicate=0，适合配置计数等命令。
数据 payload 接受范围内的负整数并编码为二补码；正整数及 `"0x..."`
或 `"0b..."` 字符串表示原始位模式。浮点值需给出明确位模式，不接受
JSON 浮点数的隐式转换。所有越界值都会报错，不静默截断。

常量队列会循环重放，消费不会释放加载槽位。工具检查同一包流中每个
Tile 的累计加载容量：Base／Streaming 为 CTRL_DEPTH，Context 为
CTRL_DEPTH+10。Context 的 TERMINATE 会重置这项计数；外部全局复位
应作为不同程序执行周期处理，不用 barrier 冒充复位或释放容量。

## 输出和驱动契约

| 文件 | 格式／用途 |
|---|---|
| `program.hex` | 每行一个完整 host packet，按实际发送顺序排列 |
| `control.hex` | 所有 CONFIG 控制字，按包序排列 |
| `constants.hex` | 所有 CONST 的完整 `data_t`，按包序排列 |
| `preload.hex` | 所有 host STORE_REQUEST 的字地址 `@hex` 与完整 `data_t`；包含重复写入 |
| `index.json` | 控制字／常量／store 对应的包下标、目标和控制地址 |
| `barriers.txt` | 每行 `发送下标 累计完成数`，下标可等于总包数表示末尾等待 |
| `manifest.json` | 位布局、计数、barrier、配置参数和输入／工具／输出 SHA256 |

驱动必须在 `val && rdy` 后才推进包下标，阻塞时保持当前包；在发送
barrier 指定下标的包之前满足其累计完成数，最后一个包后的 barrier
也必须处理。`program.hex` 本身不包含等待指令，不能忽略配套 barrier。
`preload.hex` 是地址／数据记录，实际 bank 初始化还需匹配使用者的存储
布局；本工具的端到端验收使用主机 STORE_REQUEST 完成预加载。

需要完全指定 wire 字段时，可用根字段 `packets` 替代 `steps`：每项
为 `cgra_profile.svh` 中 host_packet_t 的嵌套对象，未指定字段为零。
这种模式不应用 `control_defaults`，不添加计数、LAUNCH 或 barrier。
具名命令支持带或不带 `CMD_` 前缀，opcode 支持 `OPT_` 前缀。
数值字段仍允许按位编码保留值；能编码一个命令不表示某个 Tile 变体、
FU 或系统路由实现了它。指令步骤会检查 opcode 已定义及选择器范围，
不会宣称整个程序的调度、FU 能力和活性已被静态证明。

`abi.json` 分别记录目标 Python 的 59 个 command、99 个 opcode，
以及 SV 原生新增的 ULT／ULT_CONST／PHI_N／PHI_START_PRED。新增
opcode 不冒充原 Python 等价功能。各变体的命令和 FU 执行范围以相应
模块和功能覆盖清单为准；LoopController 的系统路由不因本工具而增加。

## 验证

```bash
make -C sv program-tools
```

检查包括：冻结 Python 测得的字段 offset／width；124 个历史主机包
逐字一致；有符号、数组顺序和非法输入；隔离目录中仅复制三个工具文件
后的标准库执行；五种 profile 的 SV 真实结构体逐字段逐位赋值；生成
架构和生成程序共同驱动的 21 PE 数学回读及 barrier，含错误结果、永久
背压和不可满足 barrier 的反例。旧文件驱动入口同时保留回归。

证据见 `reference/current/program_tools/validation.json`。
