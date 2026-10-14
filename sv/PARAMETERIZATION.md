# 参数化迁移验收

本验收分别回答三个问题：参数是否决定实际硬件、固定硬件能否加载不同程序、
相同架构和程序是否保持原 Python 的功能。结果以
`tests/parameterization/RESULTS.md` 和对应机器记录为准；有参数声明、静态展开成功、
原生数学通过、Python 对照通过是不同等级，不能相互替代。

原 Python 目标仍为 `cd7aad878915e389cecf8cc01ff6987d156bd019`，历史迁移起点为
`ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。运行前后校验原 274 个文件，并冻结
本轮开始时全部 SV RTL 的 SHA。新增测试不改 Python、RTL、原 YAML 或历史参考。

## 参数对应与支持范围

下表的“本轮”指新程序实际覆盖的参数点，不是整个合法范围的证明。组件既有
证据参见各 API 文档；本轮没有执行的能力不能借该表升级为完整整机等价。

| Python 构造参数／类型 | SV 对应 | JSON 入口 | 当前边界及本轮覆盖 |
|---|---|---|---|
| `CgraRTL.width/height` | `COLS/ROWS`，PE 数为乘积 | `architectures[].cols/rows` | SV/工具至少 2×2；本轮 2×2、3×2、2×3、3×3。Python 构造接口本身没有相同最小尺寸断言，较小尺寸不能直接宣称等价 |
| `CgraTemplateRTL.TileList` | 全矩形 PE 数与逐 PE 表 | `architectures[]` | 不支持任意稀疏删除 Tile；本轮异构 FU，不声称稀疏图等价 |
| `FuList`／逐 Tile 的 `fu_types` | `TILE_FU_COUNTS/KINDS` | `default_fus`、`fu_names` | 保留列表顺序；恰一个 Nah、最多一个对应 memory FU。原 Template 的集合排序与显式有序表需区分 |
| `FunctionUnit` 类参数 | 已实现的可配置 FU 集群 | 无任意类替换 | Python 可传类不等于 SV 可装载任意新模块；需实现 catalog 对应项 |
| `DataType` payload | `DATA_W` | `parameters.DATA_W` | 原生系统要求至少 11 位且不小于地址宽；本轮 32/64 位，64 位输入包含非零高 32 位 |
| predicate/bypass/delay 类型 | 固定 1/1/1 位 | 无 | SV 公共 ABI 固定这些宽度，不能称 Python 消息工厂的全部位宽已参数化 |
| `cgra_topology` | `TILE_PORTS` 和拓扑表 | `TILE_PORTS`、`links` | Base/Context 支持 4/8；Streaming 8。本轮普通网格与显式非几何连接 |
| `LinkList` | `CUSTOM_TOPOLOGY`、`LINK_*` | `links` | 每物理输入/输出口最多一条有向连接；本轮连接覆盖全部 PE，含禁用边和端口 4/6 |
| Tile 边界端口状态 | `BOUNDARY_IN/OUT_ENABLE` | `boundary_in/out` | 外侧 cardinal 端口；本轮 Streaming 边界输入/输出，其他程序经 SPM |
| `dataSPM` 读写口关联 | `MEM_PORTS/MEM_WRITE_PORTS`、`READ/WRITE_PORT_TILE` | `read_ports/write_ports` | 本轮自定义不同读写口数，并将入口 PE 从 tile0 改为其他 Tile |
| `ctrl_mem_size` | `CTRL_DEPTH` | 同名参数 | 至少 2；本轮 6/7，访问最后控制字；没有验证所有深度 |
| `num_registers_per_reg_bank` | `REG_DEPTH` | 同名参数 | 至少 2；本轮 2/5/7/9，低/高索引同时存活，含非二次幂 |
| `data_mem_size_per_bank` | `BANK_DEPTH` | 同名参数 | SV/工具要求至少 2 且为二次幂；本轮 8/32，回读所有位置 |
| `num_banks_per_cgra` | `NUM_BANKS` | 同名参数 | SV/工具要求二次幂；本轮 2/4，所有 bank 均初始化与回读 |
| `data_mem_size_global`／地址类型 | `GLOBAL_ADDR_W` | 同名参数 | 1…32；容纳所有窗口，本轮 7 位。非二次幂 Python 全局容量未逐项对应 |
| `num_ctrl/total_steps` | `NUM_CTRL/TOTAL_STEPS` 与配置命令 | 参数及 program 步骤 | `1≤NUM_CTRL≤CTRL_DEPTH`、总步数≤2047；本轮执行完整控制序列，不覆盖计数上限 |
| `mem_access_is_combinational` | `MEM_COMBINATIONAL` | 同名参数 | 同一 3×2 架构、程序分别运行两种模式；不预设两种模式周期相同 |
| Base/Context/Streaming 类 | `TILE_VARIANT` | `variant` | 本轮三种构造均执行程序；Context 任务迁移、STREAM_LD 专有功能仍由既有专项验证负责 |
| `has_ctrl_ring` | `cgra_system.HAS_CTRL_RING` | **尚无** | 目前仅 SV 直接参数；关闭后没有其他配置通路，只能声明断开构造能力 |
| `is_multi_cgra` | `IS_MULTI`／外层顶层 | `top` | 本轮单 CGRA、本地回环及多 CGRA 远程访问 |
| `cgra_rows/columns` | `MULTI_ROWS/COLS` | 同名参数 | Mesh 至少 2×2，Ring 单行至少两节点；本轮 3 节点 Ring、2×2 Mesh |
| `id2cgraSize_map` | `CGRA_ROWS/COLS` | 多个 architecture | 本轮 4/9/6/6 PE 混合，共 25 PE；不是任意异构参数均可逐节点改变 |
| `provided_max_*` | `MAX_COLS/ROWS/MAX_MEM_PORTS` | 同名参数 | 共享包几何必须容纳各节点；Python Template 最大几何选择规则需逐配置核对 |
| `id2ctrlMemSize_map` | 子系统可绑定深度，当前 multi 公共深度 | **工具只有公共 CTRL_DEPTH** | Python 逐 CGRA 控制深度未在工具完整对应；本轮不隐藏这一收窄 |
| `controller2addr_map` | `CUSTOM_ADDR_MAP/ADDR_MAP` | `address_map` | 等大窗口到节点的完整排列；本轮非恒等排列。Python 任意映射范围不能据此宣称覆盖 |
| `idTo2d_map` | `CUSTOM_COORD_MAP/COORD_*` | **未暴露任意坐标映射** | 本轮使用拓扑的正常坐标；不把地址窗口重排当成坐标重排 |
| 向量 FU 类型／lane 参数 | `VECTOR_LANES/FACTOR_POWER` | 同名参数 | 组合 FU factor 固定 0；native vector mul 4 lanes 等限制见向量契约。本轮标量程序未新增向量整机证明 |
| 浮点类型／格式 | `FP_EXP_W/FP_SIG_W/FP_LEGACY_PYTHON` | 同名参数 | 本轮未新增浮点程序；IEEE 原生与旧格式兼容分别验收 |
| FU `exec_lantency` 等逐项参数 | 部分独立 FU 的 latency | 无通用逐 PE 入口 | 独立 FU 参数不等于系统顶层已经完整透传 |
| `has_dma_ports/has_im2col_engine` 及外设类型 | `HAS_DMA/HAS_IM2COL`、集成顶层 | 部分公共开关 | multi 工具不暴露外设；集成 DMA 固定 32 位 CGRA 字。本轮未重跑全部外设参数 |
| FU 输入／输出数量 | 集群固定 4 入／2 出 | 无 | 原系统通常也构造为 4/2；Python 独立 FU 的其他口数不能据此认为整机均已迁移 |
| 原 NoC VC、credit、hop latency | 部分独立模块参数／顶层固定值 | 无通用入口 | 本轮仅验证当前整机网络，不声称任意 NoC 参数等价 |
| 原控制字／指令／常量 | CtrlMem 与 host packet ABI | `cgra_program.py` | 两种不同程序、三个输入 seed，每架构共用同一可执行文件；每次从复位开始，不声称在线无复位切换 |

这些边界来自构造函数、SV 参数及 `cgra_config.normalize` 的检查；不是因为某个新测试
失败后才追加的排除项。不同工具和顶层覆盖不一致的项保留为接口缺口，不自动修正。

## 固定的运行矩阵

`tests/parameterization/generate.py` 定义九种架构，默认原生模式，不开启任何 legacy
开关。每种架构编译一次，用同一二进制运行 add、affine 两个程序，seed=0/23/917，
分别无背压和确定性随机背压，共 108 次正向运行。add 在所有架构计算 `x+17`，affine
计算 `3*x+11`（按 DATA_W 截断）；映射器分配中间运算并在末尾补偿偏移，独立 oracle
仅计算这两个公式。seed=0 含全 1/零边界；64 位随机
输入使用全部位宽。相同 3×2 架构另以寄存返回模式构建，程序内容不因结果而修正。

每个 PE 参与从 SPM 出发的全阵列计算链和返回路径；Streaming 以公开边界端口输入
和输出，仍独立检查 SPM 主机访问。程序经过最后控制字，访问寄存器 0 和最高索引。
专门的隔离步骤先保存低索引值，再写入并消费高索引的另一个值，最终结果必须保持
低索引值。全部 SPM 先经主机写入，程序结束后逐字回读，包括未应改动的保护位置。
实际指令以 `program.json`／`program.hex` 为准；`specification.json` 的 `stages`
保留映射器中间账目，pc2/pc3 随后改为寄存器隔离步骤，不是可执行指令清单。
独立数学检查不读取该账目。

测试台只实现握手、输入保持、输出背压、完成 barrier、有界结束和 32 周期排空。
算法结果由独立 Python 数学检查产生，不从 DUT 输出或者生成的控制字反推。完整
完成数、来源 Tile、存储地址/owner、predicate、重复/缺失输出都参与验收。
这里核对最终存储内容，不宣称每次内部访存事件及其周期都已逐项等价。

每架构加入最后一个 PE 指令损坏、寄存器索引全部归零、永久输出阻塞三个反例。
反例只有出现预期数学错误或有界硬件超时才算检出；构建错误、工具异常不算。

每架构的两个 seed=23 程序还在原 Python 上执行，并与 SV 完整已接受消息比较。
允许不同独立 PE 的完成消息交错；主机读请求串行发送，因此读回序列逐项一致。
这项对照不声称 reset/invalid 消息位、内部仲裁周期或者全部微架构状态逐周期等价。

## 运行与证据

```sh
python3 -B sv/tests/parameterization/run.py --output work/parameterization \
  --python /path/to/original-pymtl/bin/python
```

使用维护版 Verilator 工具链运行 SV，原 Python 只在指定解释器子进程内导入。原模型
通过构造参数和已有测试采用的 `set_param` 设置 FU 名单；不替换运算逻辑，不写内部
寄存器或 bank。支持 `--profiles` 缩小诊断范围；`--smoke` 只检查一个输入，均不能
得到全矩阵通过结论。失败保留并继续其他架构，原来四个未完成用例也仍保留，不因本轮
新程序通过而改成原用例通过。

参考工具自身的直接缓存要求源码目标、工具、架构、程序、数学规格、调度和轨迹哈希
均一致，`--fresh` 强制重新模拟。批量运行器也能复核已生成的冻结参考：核对原源码
目标、架构/程序/轨迹 SHA，再用当前 oracle 及当前 SV 完整消息重新比较；它保留
原采集记录，不要求把历史采集器冒称为当前版本。两种复用都明确标记，不描述为再次
执行原 Python。新输出目录会重新采集；`--reference-jobs` 控制独立参考的并发数。
早期冻结记录缺少部分采集元数据（如调度字段）时，仅按当前数学结果和完整消息复核，
不把缺少的字段补写成已记录的证据；新采集记录包含调度及参考工具哈希。
