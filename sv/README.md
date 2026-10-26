# VectorCGRA 原生 SystemVerilog：上手与测试

这是 VectorCGRA 从 Python／PyMTL RTL 迁移到原生 SystemVerilog 的实现。
可以配置 PE 阵列、功能单元（FU）、存储和连接关系，再通过主机接口加载程序运行。
当前硬件入口是 `rtl/tile/cgra_pe.sv` 和 `rtl/cgra/cgra_system.sv`，不是固定 2×2 顶层。

**第一次使用，建议依次完成：安装工具 → 跑通现成 ReLU → 查看结果 → 修改架构配置。**
本文命令均在 **Git 仓库根目录** 执行；文档中的相对链接和目录树则以 `sv/` 为基准。

原生 SV 仿真不需要运行原项目 Python RTL 或安装 PyMTL。配置、程序打包和回归脚本
使用 Python 3；JSON 工具只需标准库，YAML 入口另需 PyYAML。

## 1. 项目目录与主要入口

```text
仓库根目录/
├── cgra/、tile/、fu/、mem/、noc/、multi_cgra/ …  原 Python RTL 与测试
└── sv/
    ├── rtl/                  当前维护的硬件实现
    │   ├── cgra/             单 CGRA、同构／异构多 CGRA 顶层
    │   ├── tile/             参数化 PE、Base／Context／Streaming 实现
    │   ├── fu/               标量、向量、浮点及组合 FU
    │   ├── mem/              控制／常量存储、寄存器组、数据存储
    │   ├── noc/              互连、路由器、交换和握手组件
    │   ├── controller/       主机命令处理、全局归约等
    │   ├── peripheral/       DMA、im2col 等外设
    │   ├── common/           公共参数、消息类型、端口和 FU catalog
    │   └── vendor/           当前实现使用的第三方 RTL
    ├── filelists/            HDL 构建清单；当前 DUT 使用 native.f
    ├── tools/                架构 JSON、程序 JSON、映射 YAML 的处理工具
    ├── examples/
    │   ├── config/           可校验的架构 JSON 示例
    │   ├── program/          与架构配套的主机程序 JSON
    │   └── yaml/             ReLU、修正后的 add_one 等映射示例
    ├── tests/
    │   ├── current/          当前组件、PE、内核和系统的 SV 台架／运行脚本
    │   ├── config/           配置／打包／YAML 工具和生成参数的测试
    │   ├── parameterization/ 跨架构、多程序和 Python 功能对照
    │   ├── original/         原 Python 测试的对应验证与缺口记录
    │   ├── scripts/          回归、打包和工程辅助脚本的测试
    │   └── legacy/           历史 DUT 与旧入口
    ├── reference/            冻结参考、golden HDL、轨迹和验收证据
    ├── scripts/              工具链安装、统一回归、综合及独立导出
    ├── results/              已记录的实验结果与索引
    ├── licenses/             依赖许可、来源与散列记录
    ├── migration_tools/      生成／采集 Python 参考的迁移工具
    ├── docs/                 迁移介绍及完整文件导览
    ├── build/                本地生成的工具链、可执行文件、日志和测试结果
    └── Makefile              常用测试和综合目标
```

| 想做什么 | 从哪里开始 |
|---|---|
| 测一个 PE | `rtl/tile/cgra_pe.sv`、`tests/current/tb_current_pe.sv` |
| 集成一个可编程 CGRA | `rtl/cgra/cgra_system.sv` |
| 多 CGRA Mesh／Ring | `rtl/cgra/cgra_multi.sv` |
| 异构尺寸／逐 PE FU 配置 | `rtl/cgra/cgra_multi_template.sv`、`tools/cgra_config.py` |
| 运行已有 ReLU YAML | `tests/current/run_relu_yaml.sh` |
| 查数据／控制／主机包字段 | `rtl/common/cgra_profile.svh`、`tools/abi.json` |
| 查 FU 名称与静态编号 | `rtl/common/cgra_fu_catalog.svh` |
| 查看逐文件用途与迁移过程 | [文字导览](docs/migration-guide.md)、[HTML 导览](docs/migration-guide.html) |

`tests/legacy/` 和 `reference/legacy/` 中的旧 2×2 包装等不属于当前核心硬件。
迁移后的路径和历史入口见 [RTL_LAYOUT.md](RTL_LAYOUT.md)。`licenses/` 用于许可和来源追溯，
不是仿真输出目录；第三方依赖的使用条件见 [DEPENDENCIES.md](DEPENDENCIES.md)。

## 2. 安装仿真工具

推荐 Linux x86_64。需要 Python 3、支持 C++20 的编译器、Make、Perl、curl、tar、unzip。
例如 Ubuntu 24.04 可先安装系统依赖：

```bash
sudo apt-get update
sudo apt-get install -y build-essential python3 python3-venv python3-yaml perl curl tar unzip
```

安装仓库锁定的工具链并启用：

```bash
python3 sv/scripts/install_toolchain.py
source sv/build/toolchain/env.sh
verilator --version
yosys -V
sv2v --version
python3 -c 'import yaml; print(yaml.__version__)'
```

安装器校验下载文件 SHA256。锁定版本为 Verilator 5.029、Yosys 0.45+139、sv2v 0.0.13，
具体版本由 `scripts/toolchain.lock.json` 管理。每个新终端都需重新 `source`。
Verilator 用于仿真，sv2v／Yosys 用于综合及综合网表验证。

若系统没有 `python3-yaml`，可在自己的虚拟环境中安装：

```bash
python3 -m venv .venv-sv
source .venv-sv/bin/activate
python3 -m pip install PyYAML
source sv/build/toolchain/env.sh
```

普通 JSON 工具无需 PyYAML。原 Python 对照测试才需要额外安装项目指定的 PyMTL fork，
其工具链与原生 SV 不同，不能用原生 Verilator 的版本要求替代原 Python 的要求。

## 3. 第一个完整测试：4×4 ReLU

已有映射计算 32 个有符号 int32 的 `output[i] = max(input[i], 0)`。
默认输入是 `[-16, -15, …, 15]`；输出应为 17 个零，再接 `1, 2, …, 15`。

```bash
source sv/build/toolchain/env.sh
bash sv/tests/current/run_relu_yaml.sh \
  sv/examples/yaml/relu_neura_pass.yaml \
  sv/build/tutorial/relu-default
```

输出目录必须尚不存在。重新运行时使用新的目录名，或省略第二个参数，让脚本创建带时间戳的目录：

```bash
bash sv/tests/current/run_relu_yaml.sh sv/examples/yaml/relu_neura_pass.yaml
```

首次运行会编译原生 SV CGRA。后续运行按源码、台架、参数和工具版本指纹复用可执行文件，
每次重新解析传入的 YAML。脚本执行正常握手和主机背压／发送间隔两种场景，
检查全部 32 个结果、实际 STORE 次数，以及 RETURN 是否发生在写入完成之后。

**验收标准：命令退出码为 0，且最后出现 `RELU_YAML_PASS`。**
`NATIVE_KERNEL_MATH_PASS`、`NATIVE_STORE_COUNTS_PASS` 是内部检查标记；
只有其中一个标记，或只有可执行文件生成，都不能代表整个测试通过。

| 输出文件（位于指定输出目录） | 如何使用 |
|---|---|
| `normal.log`、`backpressure.log` | 检查两次运行的成功标记、周期或错误 |
| `results-normal.csv`、`results-backpressure.csv` | 查看逐地址实际回读和独立数学期望，数值为十六进制 |
| `config.json`、`verilator.args` | 查看实际构建的架构和 SV 参数 |
| `program.json`、`program.hex` | 查看从本次 YAML 生成的配置／启动消息与输入预加载 |
| `input.json`、`expected.hex` | 查看输入与 `max(x,0)` 期望 |
| `stores.txt`、`return.hex` | 写入次数和完成包检查条件 |
| `manifest.json`、`build-stamp.json` | 输入、生成物、源码与工具的构建身份 |

编译日志在 `sv/build/current/yaml-relu/memory1/compile.log`。
失败时可能留下部分结果文件，请以整个 runner 的退出状态为准。

### 换一组输入

以下示例生成另一组 32 元素输入；期望由测试脚本独立计算：

```bash
mkdir -p work/readme
python3 - <<'PY'
import json
from pathlib import Path
values = [-(1 << 31), -1, 0, 1, (1 << 31)-1, -17, 17, 42] * 4
Path('work/readme/input.json').write_text(json.dumps(values) + '\n')
PY
bash sv/tests/current/run_relu_yaml.sh \
  sv/examples/yaml/relu_neura_pass.yaml \
  sv/build/tutorial/relu-boundaries \
  work/readme/input.json
```

输入必须恰好是 32 个有符号 int32。

### 这个入口的支持范围

此 runner 对应 **4×4、Base PE、32 位、II=5、TOTAL_STEPS=170、组合内存返回** 的 ReLU。
YAML 已经包含映射和调度；前端不负责把任意 C++／DFG 自动映射到硬件。
换算法、循环上界或阵列尺寸后，需要相应程序和数学检查器。

这份映射在 `RELU_MEMORY=0` 的寄存返回模式下，会在只完成 31／32 次 STORE 时返回，
属于保留的失败反例；原 Python 同模式也能复现。正常上手请保留默认 `RELU_MEMORY=1`。
前端 opcode、格式及内存时序说明见 [YAML_RELU.md](YAML_RELU.md)。

## 4. 参数化：架构、程序和测试分别配置什么

| 配置对象 | 输入 | 生效时机 | 例子 |
|---|---|---|---|
| 硬件架构 | 架构 JSON → `architecture.svh`／`bindings.svh`，或直接绑定 SV 参数 | 展开／编译时；变化后重新构建 | 4×4 改 3×2、32 位改 64 位、选择 FU |
| 运行程序 | 程序 JSON，或支持的已映射 YAML → host packet | 仿真中通过主机 `val/rdy` 加载 | 控制字、路由、常量、启动和迭代次数 |
| 验收条件 | 台架、输入和数学期望 | 每次运行 | ReLU 的 32 个输出、背压、结束条件 |

PE 的数量由 `cols × rows` 决定。单独实例化 `cgra_pe` 只得到一个 PE，
其中的 `COLS/ROWS` 用于所属系统的地址／消息类型。

### 4.1 用 JSON 生成架构

下面创建 **3 列 × 2 行、6 个 Base PE** 的架构。此例用于讲解硬件配置，
不直接适配上节固定 4×4 的 ReLU 程序。

```bash
mkdir -p work/readme
cat > work/readme/architecture.json <<'JSON'
{
  "schema": 1,
  "top": "system",
  "variant": "base",
  "parameters": {
    "DATA_W": 32,
    "TILE_PORTS": 4,
    "CTRL_DEPTH": 6,
    "NUM_CTRL": 5,
    "TOTAL_STEPS": 170,
    "REG_DEPTH": 8,
    "NUM_BANKS": 2,
    "BANK_DEPTH": 16,
    "GLOBAL_ADDR_W": 7,
    "MEM_COMBINATIONAL": 1
  },
  "default_fus": ["ADDER", "MUL", "MEM", "NAH"],
  "architectures": [{"cols": 3, "rows": 2}]
}
JSON
python3 -I -S sv/tools/cgra_config.py work/readme/architecture.json --check
python3 -I -S sv/tools/cgra_config.py work/readme/architecture.json \
  --output work/readme/generated-architecture
```

`--check` 仅校验；生成目录必须不存在。输出包括：

- `architecture.svh`：派生位宽、`CFG_*` 参数及 `ARCH_*` 静态表。
- `bindings.svh`：对应硬件顶层的具名参数绑定。
- `manifest.json`：规范化配置、派生参数及 SHA256。

集成时，在调用方模块内包含 `architecture.svh`，在 `cgra_system #(...)` 内包含
`bindings.svh`，并连接该顶层的完整端口；编译时添加生成目录的 include 路径。
**生成头文件不会自动创建时钟、测试台或加载程序。** 完整连接示例和生成参数的
真实展开测试见 [CONFIGURATION_TOOL.md](CONFIGURATION_TOOL.md) 及
`tests/config/prepare_hdl_checks.py`。

### 4.2 常用参数与约束

以下默认值指 **JSON 配置工具** 的默认值；具体台架／ReLU 入口会显式覆盖部分参数。

| JSON 位置／参数 | 默认值 | 含义和支持条件 |
|---|---|---|
| `top` | `system` | 单 CGRA；`multi` 为多 CGRA |
| `variant` | `base` | `base`／`context`／`streaming`；单 PE 的 SV 参数为 `VARIANT=0/1/2` |
| `architectures[].cols/rows` | 必填，或用 `size` | 每个本地矩形阵列的列／行数，各至少 2；不能任意删除 PE |
| `DATA_W` | 32 | 数据 payload 位宽，至少 `max(11, GLOBAL_ADDR_W)`；已有 32／64 位验证 |
| `TILE_PORTS` | 4 | Base／Context 支持 4 或 8，Streaming 必须为 8 |
| `CTRL_DEPTH` | 8 | 每 PE 控制存储深度，至少 2 |
| `NUM_CTRL` | 8 | 控制序列长度，1…CTRL_DEPTH；降低控制深度时同时调整它 |
| `TOTAL_STEPS` | 8 | 控制步预算，0…2047；一个控制步可能持续多个时钟周期 |
| `REG_DEPTH` | 16 | 每个寄存器 bank 的深度，至少 2；每 PE 四个 bank，允许非二次幂 |
| `NUM_BANKS` | 2 | 每 CGRA 的数据存储 bank 数，至少 1 且为二次幂 |
| `BANK_DEPTH` | 16 | 每 bank 的字数，至少 2 且为二次幂；容量为 NUM_BANKS × BANK_DEPTH 个字 |
| `GLOBAL_ADDR_W` | 7 | 全局**字地址**位宽，1…32；须容纳所有 CGRA 的存储窗口 |
| `MEM_COMBINATIONAL` | 1 | 1 为组合返回，0 为带时序通道的模式；程序须匹配访存时序 |
| `MULTI_COLS/ROWS` | 1／1 | 多 CGRA 的列／行数；`architectures` 数量必须等于二者乘积 |
| `topology` | `mesh` | `multi` 支持 Mesh（至少 2×2 节点）或 Ring（单行、至少 2 节点） |
| `HAS_DMA/HAS_IM2COL` | 0／0 | 单 CGRA 的可选外设；multi 顶层不提供这些外设端口，集成 DMA 要求 DATA_W=32 |
| `VECTOR_LANES` | 4 | 向量 lane 数，须整除 DATA_W；原生 VECTOR_MUL 当前恰为 4 lanes |
| `VECTOR_FACTOR_POWER` | 0 | 当前组合 FU 集群要求为 0 |
| `FP_EXP_W/FP_SIG_W` | 8／23 | 浮点指数／小数字段宽度，DATA_W=1+二者之和；具体格式约束由工具检查 |
| `*_LEGACY_PYTHON` | 0 | MEMORY／NOC／FP／REDUCE／VECTOR／ARITH 的兼容行为开关；原生测试通常保留 0 |

`MEM_PORTS`、`MEM_WRITE_PORTS`、`MAX_MEM_PORTS`、`MAX_COLS/ROWS`、`FU_COUNT`
等容量按架构表推导；显式设置时必须足够容纳对应表。消息位宽也是派生值，
不要手工沿用另一种架构的控制包宽度。完整检查以 `tools/cgra_config.py` 为准。

### 4.3 选择 FU、修改连接和多 CGRA

- 根字段 `default_fus` 为所有 PE 提供有序 FU 名单。默认是 `ADDER, MUL, MEM, NAH`；
  Streaming 默认用 `STREAMING_MEM` 替代 `MEM`。每个 PE 恰含一个 `NAH`，最多一个
  对应类型的内存 FU，也可不带内存 FU。**FU 顺序会保留，不要排序或改成集合。**
- `architectures[].fu_names` 可为每个 PE 分别指定名单，列表长度必须等于 PE 数。
  可选项包含 `COMP`、`LOGIC`、`SHIFTER`、`SEL`、`PHI`、`GRANT`、`RET`、除法、
  向量、浮点及组合 FU；完整名称见 `tools/cgra_config.py` 的 `FU_NAMES/FU_KINDS`。
  新增 FU 类型需要实现 RTL 并接入 catalog；不能直接传入任意 Python 类。
- Tile 编号为 `y*cols+x`。端口 0=N、1=S、2=W、3=E，北方增加 y；
  8 端口时 4=NW、5=NE、6=SE、7=SW。省略 `links` 时生成对应规则网格。
- `links` 指定有向边的 `src/dst/sp/dp/enabled`。同一输入或输出口不能被多条启用边占用。
  `boundary_in/out` 是逐 PE 边界端口位掩码，不能与内部连接重复占口。
- `read_ports/write_ports` 指定存储端口连接的 PE 编号；`null` 表示未连接。
  省略时连接西侧一列及南侧一行，原点不重复。显式空列表表示没有这些连接。
- 多 CGRA 用 `top="multi"`，提供逐 CGRA 的 `architectures`；可配置不同本地尺寸和 FU。
  `address_map` 重排地址窗口归属，不改变物理坐标。

可参考：`examples/config/context64.json`、`streaming.json`、`ring.json`、`heterogeneous.json`。
通用 FU 集群接口仍为 4 输入／2 输出；任意 VC／credit、稀疏删除 PE、逐 CGRA 不同控制深度
没有统一 JSON 入口。`HAS_CTRL_RING` 当前仅为 SV 直接参数，设为 0 后没有替代配置／启动通路。
静态校验通过表示满足构造约束，不表示任意程序、数值格式和参数组合均已验证。
完整对应表见 [PARAMETERIZATION.md](PARAMETERIZATION.md)。

## 5. 加载自己的程序

架构 JSON 决定硬件；程序 JSON 决定往这套硬件发送哪些控制字、常量和主机命令。
程序中包含 PE 指令及路由，因此必须与架构、FU 和访存模式匹配。

先使用仓库中配套的完整异构示例校验和打包：

```bash
python3 -I -S sv/tools/cgra_program.py \
  --config sv/examples/config/heterogeneous.json \
  --program sv/examples/program/heterogeneous.json --check
python3 -I -S sv/tools/cgra_program.py \
  --config sv/examples/config/heterogeneous.json \
  --program sv/examples/program/heterogeneous.json \
  --output work/readme/generated-program
```

程序 JSON 的 `steps` 按序包含 `preload`、`constants`、`program`、`command`、`barrier`，
也可直接提供完整 `packets`。输出为 `program.hex`、`control.hex`、`constants.hex`、
`preload.hex`、`barriers.txt`、`index.json`、`manifest.json`。具体字段和例子见
[PROGRAM_TOOL.md](PROGRAM_TOOL.md)。

**打包成功只表示配置包已生成，尚未执行硬件。** 可运行仓库已有的完整
21 PE 示例台架，检查配置生成、消息加载、barrier 与数学回读：

```bash
bash sv/tests/config/run_program_kernel.sh
```

自定义程序需要提供对应输入和期望，并接入实际仿真台架。可参考上述 runner 及
`tests/current/tb_native_kernel.sv`；驱动要在 `val && rdy` 后推进包下标，阻塞时保持消息，
并处理 `barriers.txt` 指定的等待条件。当前分支尚无任意架构／任意算法的统一数学 runner。

YAML 是另一种程序输入。它不是被写进架构 JSON，而是通过 `cgra_yaml.py` 转成
程序配置包；现成 ReLU runner 同时生成与之匹配的 `config.json`。仅翻译而不仿真：

```bash
python3 sv/tools/cgra_yaml.py \
  --yaml sv/examples/yaml/relu_neura_pass.yaml \
  --total-steps 170 --output work/readme/generated-relu
```

### 5.1 不用 ReLU：运行仓库已有的其他例子

已有 runner 会完成编译、装载、运行和断言检查。启用工具链后，在仓库根目录选择：

| 想测什么 | 命令 | 检查含义 |
|---|---|---|
| AXPY：向量乘常数后相加 | `bash sv/tests/current/run_kernel_boundaries.sh all axpy` | 独立数学结果、写入次数、完成顺序、背压和两种内存模式 |
| GEMM：矩阵乘法 | `bash sv/tests/current/run_native_kernels.sh gemm` | 原生修正程序的数学结果及错误结果／超时负例 |
| GEMV：矩阵乘向量 | `bash sv/tests/current/run_native_kernels.sh gemv` | 原生修正程序的数学结果及负例 |
| SPMV／COO 稀疏矩阵程序 | `bash sv/tests/current/run_native_kernels.sh spmv spmv_coo` | 对应原生程序及其台架检查；SPMV 另含 nnz／背压场景 |
| FIR／Histogram／SAD | `bash sv/tests/current/run_kernels.sh fir4x4 histogram sad` | 选定兼容模式下的冻结 Python 周期轨迹对照 |
| 异构 21 PE 程序 | `bash sv/tests/config/run_program_kernel.sh` | 架构／程序生成、主机装载、barrier 和数学回读 |

这些命令的输入规模和程序已由对应 fixture 指定，并非任意尺寸的算法库。
`run_native_kernels.sh` 使用 `reference/native/kernels/<name>/`，日志在
`sv/build/native/<name>/`；AXPY 边界台架日志在 `sv/build/current/kernel-boundaries/axpy*`；
冻结轨迹台架日志在 `sv/build/current/kernels/<name>/`。

原生修正程序的数学通过，不等于原 Python 原始程序已经通过；冻结周期对照通过，
也不等于新增任意输入的数学验证。选用 runner 前先确认所需的验证目标。

### 5.2 自己写一个例子：建议从 add_one 开始

例如测试 `data[i] = data[i] + 1`，可以按下面的步骤接入：

1. 固定输入与独立期望，例如 32 个输入 `0…31`、期望 `1…32`，明确读写地址。
2. 选择架构 JSON，确定数据宽度、FU、阵列尺寸、存储模式和控制深度。
3. 提供与架构匹配的映射／调度。可手写程序 JSON，或使用当前前端支持的已映射 YAML；
   C++ 本身不能直接交给这些工具编译运行。仓库中的 `examples/yaml/add_one_4x4_fixed.yaml`
   可作为映射参考，但没有一个现成的通用 add_one 数学 runner。
4. 用 `cgra_program.py` 或 `cgra_yaml.py` 生成配置包，确保架构和程序使用同一套位宽布局。
5. 接入台架：通过主机写入输入、发送配置和启动命令、等待程序完成，再回读输出。
   可参考 `tb_native_kernel.sv` 和 `tb_native_template.sv`；现有台架有特定的结果格式和约束，
   接入新算法时应检查并适配，不能仅替换 YAML 后保留 ReLU 的期望。
6. 以独立数学公式比较所有输出，检查写入范围、次数和结束时序，并增加超时上限。
7. 用正常握手、背压、边界输入和至少一个故意错误的负例验证检查器能检出问题，
   然后把新 runner 加入 `scripts/regression.json`。

如果只是改变输入，且算法、尺寸和布局都不变，通常可以复用同一仿真二进制；
改变硬件架构参数必须重新构建。改变程序是否需要重新构建，还取决于该台架是否将
程序作为运行时文件读取，不能假定所有历史台架都支持运行时换程序。

## 6. 按需求运行测试

```bash
# 不需要 HDL 工具的前端检查
python3 -I -S sv/tests/config/test_config.py
python3 -I -S sv/tests/config/test_program.py
python3 sv/tests/config/test_yaml.py

# 原生 FU、状态、PE 变体、DMA 及系统读写检查
make -C sv current

# 架构生成、实际 HDL 展开及程序端到端检查（需要 Verilator）
make -C sv config-tools
make -C sv program-tools

# ReLU 正向／负向回归；包含预期失败的寄存内存反例
make -C sv native-yaml-relu

# 查询统一回归清单，先运行一个分组
python3 sv/scripts/regression.py --check-catalog
python3 sv/scripts/regression.py --list
python3 sv/scripts/regression.py --shard core

# 完整回归：14 组、49 个目标，包含综合与综合网表验证
make -C sv regression
```

完整回归耗时和资源高于单内核测试。大型系统／Mesh 网表验证建议独占 16 GiB 内存，
减少并行构建可设置 `export JOBS=1`；这不保证所有参数规模均能在该内存内运行。
统一回归的退出码、版本、源码 SHA 和日志位于 `sv/build/regression/<shard>/`，
详细资源要求和历史证据见 [REGRESSION.md](REGRESSION.md)。

这些测试分别覆盖原生数学、选定 Python 兼容轨迹、协议、参数展开及负例；
它们的通过范围不同。原始测试对应缺口见 `tests/original/RESULTS.md`、`FOLLOWUP.md`，
参数化实际运行矩阵见 [tests/parameterization/RESULTS.md](tests/parameterization/RESULTS.md)。

## 7. 常见问题

| 现象 | 处理方式 |
|---|---|
| `verilator: command not found`／`sv2v: command not found` | 安装工具链，并在当前终端 `source sv/build/toolchain/env.sh` |
| YAML 报 `No module named yaml` | 为运行脚本的 Python 安装 PyYAML；JSON 工具无需它 |
| 输出目录已存在 | 使用新的生成／运行目录；工具会拒绝覆盖 |
| `NUM_CTRL` 超过 `CTRL_DEPTH` | 同时调整控制深度与序列长度，重新校验架构 |
| bank／地址宽度报错 | bank 数、深度满足二次幂约束，全局地址覆盖全部存储窗口 |
| YAML 不支持的 opcode／格式 | 先查 [YAML_RELU.md](YAML_RELU.md)；当前前端不支持任意 Mapper 输出 |
| `KERNEL_MATH`／结果不符 | 检查输入、数学期望、映射、FU 选择和寄存器／路由配置 |
| `KERNEL_EARLY_RETURN` | 检查完成依赖及 STORE 是否全完成；ReLU 的寄存内存模式已有失败反例 |
| 超时 | 查看编译与运行日志，检查配置是否到达、操作数／常量是否齐备、握手／barrier 是否堵塞 |
| 只生成了 hex，但没有结果 | 程序打包与仿真是两步；使用匹配的台架运行 |
| 工具版本变化后面积／周期不同 | 对齐提交、参数、版本、脚本、库和约束，重新构建后比较 |

## 8. 迁移范围与后续阅读

迁移历史起点是 `ac96a7af`，固定 Python 目标为 `cd7aad878915`（Python 内容来自父提交
`e3caf6928a4e`）。原 274 个 Python 文件保持不变。当前实现支持明确范围内的功能对应；
原生修正行为与显式兼容模式分别验收，不宣称所有参数、程序或内部状态全面逐周期等价。

独立 LoopController 的整机路由、可扩展存储远程接口等仍有集成边界。
当前 README 的测试命令不代表 FPGA／ASIC 时序或面积已达标；综合需要另行固定平台、
标准库、脚本及约束，并验证综合后的功能。

- [CURRENT_MIGRATION.md](CURRENT_MIGRATION.md)：当前进度、语义差异和集成边界。
- [CONFIGURATION_TOOL.md](CONFIGURATION_TOOL.md)：架构 JSON 全部字段与静态约束。
- [PROGRAM_TOOL.md](PROGRAM_TOOL.md)：程序配置、主机包和 barrier 契约。
- [PE_INTERFACES.md](PE_INTERFACES.md)：PE 参数、端口与变体语义。
- [STANDALONE.md](STANDALONE.md)：独立导出、完整性检查及脱离原 Python 的构建。
- [FINAL_ACCEPTANCE.md](FINAL_ACCEPTANCE.md)：分项验收与证据入口。
- [MIGRATION_INVENTORY.md](MIGRATION_INVENTORY.md)、[MIGRATION_TASKS.md](MIGRATION_TASKS.md)：文件清单和迁移任务。
