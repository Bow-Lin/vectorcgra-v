# 独立架构配置工具

`tools/cgra_config.py` 将显式 JSON 架构转换成维护版 SV 顶层的静态参数。
只需要 Python 3 标准库，不导入 VectorCGRA、PyMTL 或 migration_tools。
生成的配置供 `cgra_system` 或 `cgra_multi_template` 使用；阵列、PE 和
FU 仍由原有参数化 SV 模块展开。它不进行程序映射或生成固定阵列 RTL。

```bash
python3 -I -S sv/tools/cgra_config.py sv/examples/config/system.json --check
python3 -I -S sv/tools/cgra_config.py sv/examples/config/heterogeneous.json \
  --output work/my-cgra
```

输出目录必须不存在，避免覆盖已有配置。输出包含：

- `architecture.svh`：`CFG_*` 参数／消息宽度和 `ARCH_*` 静态表。
- `bindings.svh`：顶层实例的具名参数绑定。
- `manifest.json`：规范化配置、派生宽度以及输入、工具和两个头文件的 SHA256。

在调用者模块内包含 `architecture.svh`，然后在对应顶层的 `#(...)`
中包含 `bindings.svh`。按该顶层的公开接口连接时钟、复位、消息和边界端口。
例如多 CGRA 主机接口消息位宽为 `CFG_HOST_BITS`：

```systemverilog
module configured_fabric (
  // Port declarations belong to the caller's integration wrapper.
);
  `include "architecture.svh"
  logic clk, reset;
  logic [CFG_HOST_BITS-1:0] recv_from_cpu_pkt__msg, send_to_cpu_pkt__msg;
  logic recv_from_cpu_pkt__val, recv_from_cpu_pkt__rdy;
  logic send_to_cpu_pkt__val, send_to_cpu_pkt__rdy;
  cgra_multi_template #(
    `include "bindings.svh"
  ) dut(.*);
endmodule
```

该片段只展示参数用法；时钟、复位、主机输入须由实际系统或测试台驱动。
`system` 顶层还要连接边界、地址窗口和其公开的外设接口。

## 输入格式

最小配置：

```json
{
  "schema": 1,
  "top": "system",
  "architectures": [{"cols": 3, "rows": 2}]
}
```

`top` 为 `system` 或 `multi`；`variant` 为 `base`、`context` 或
`streaming`，默认 `base`。`topology` 只对 `multi` 生效，可选 `mesh`
或 `ring`。多 CGRA 配置必须显式给出 `parameters.MULTI_COLS` 和
`MULTI_ROWS`，并提供同样数量、按 `y*MULTI_COLS+x` 排列的架构。

`parameters` 接受 SV 公共参数的名称：数据／控制／寄存器／bank 大小、
全局地址宽度、4／8 个 Tile 端口、读写端口数量、外围功能开关、各类
兼容模式和向量／浮点参数。整数开关使用 0 或 1。未知参数和派生宽度
不能悄悄被忽略或覆盖。`COLS/ROWS` 从最大的本地尺寸确定，
`MAX_COLS/MAX_ROWS` 可显式增加共享消息几何范围；未指定的端口容量及
FU 表容量按实际表计算。完整默认值见工具的 `DEFAULTS`。

每个 `architectures` 条目包含：

| 字段 | 含义 |
|---|---|
| `cols`, `rows` | 至少 2×2 的本地 Tile 阵列；方阵也可用 `size` |
| `fu_names` | 每个 Tile 的有序 FU 名单，不能省略单个 Tile |
| `links` | 显式有向连接：`src`, `dst`, `sp`, `dp`, `enabled`（0／1） |
| `read_ports`, `write_ports` | 各存储端口对应 Tile 编号；`null` 或 4294967295 为未连接 |
| `boundary_in`, `boundary_out` | 每 Tile 的端口位掩码，bit 0=N、1=S、2=W、3=E |

Tile 编号为 `y*cols+x`，北方增加 y。未指定 `links` 时生成 4 端口
Mesh 或 8 端口 KingMesh；对角口 4=NW、5=NE、6=SE、7=SW。
未指定边界表时启用所有外侧 cardinal 端口；未指定存储表时依次连接
西边一列、南边一行（不重复原点）。显式空列表表示没有对应连接，
不会自动恢复默认连接。为兼容冻结表，边界列表允许末尾补零。

默认 FU 为 `ADDER, MUL, MEM, NAH`；Streaming 使用 `STREAMING_MEM`。
根字段 `default_fus` 可替换这一名单，每 Tile 的 `fu_names` 再覆盖它。
FU 名称对应 `cgra_fu_catalog.svh` 中的 `CGRA_FU_*` 后缀，也接受工具
明确列出的原 Python 类名别名。槽位顺序原样保留，不能用无序集合代替。
至少且只能有一个 `NAH`；允许没有 memory FU。

可选根字段 `address_map` 是“地址窗口序号 → CGRA ID”的完整排列。
例如 `[2,0,3,1]` 将窗口 0 分配给 CGRA 2；不改变物理拓扑坐标。
工具不提供任意坐标重映射、稀疏删除 Tile 或任意 VC／credit 扩展。

## 拒绝的配置

校验包括尺寸／容量／位宽、控制条目范围、bank 的二次幂约束、端口
数量、FU 名称及内存种类、向量 lane 和浮点宽度契约。启用的连接不能
重复占用同一输入或输出口，不能与边界口重叠；边界只能位于正确的外侧
cardinal 端口，同一 Tile 不能重复连接多个读口或多个写口。

Context／Base 的 memory FU 必须为 `MEM`，Streaming 必须为
`STREAMING_MEM`；两者都可以不配置 memory FU。SV 公共存储连接层也
检查这个约束，绕过工具手工实例化错误目录仍会报 `PE_MEMORY_VARIANT`。

多 CGRA Mesh 至少 2×2，Ring 至少两个节点且只有一行。多 CGRA 顶层
没有 DMA／im2col 端口，工具会拒绝打开它们。单 CGRA 的集成 DMA
仍要求 32 位数据。工具通过表示该配置满足静态接口约束，不代表任意
程序都能执行，也不扩大现有 RTL 的功能／数值精度承诺。

## 验证

```bash
make -C sv config-tools
```

检查包含标准库隔离执行、可重复输出和拒绝覆盖、故意错误的图／FU／
参数配置、冻结异构表逐项对比，以及实际顶层的展开和 SV 类型宽度检查。
五份示例覆盖单 CGRA、64 位 Context、Streaming、多 CGRA Ring 及
2×2／3×3 混合的异构 Mesh。生成的异构参数还用于实际 21 个 PE 的
程序运行，以独立算式检查 8 次最终回读，包含错误结果和永久阻塞反例。

证据保存在 `reference/current/config_tools/validation.json`。程序／常量／
预加载／主机命令的独立打包工具见 [PROGRAM_TOOL.md](PROGRAM_TOOL.md)。
