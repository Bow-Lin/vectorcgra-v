# VectorCGRA SystemVerilog

当前维护版位于 `sv/rtl/`，DUT 文件清单为 `sv/filelists/native.f`。硬件直接由
SystemVerilog 参数和 generate 展开；普通仿真、综合和程序加载不依赖原项目 Python
或 PyMTL。JSON 配置和回归工具使用 Python 3 标准库；可选 YAML 前端另需 PyYAML。

迁移的历史起点是 `ac96a7af`；本轮固定 Python 目标为 `cd7aad878915`，其 Python 内容
来自父提交 `e3caf6928a4e`。原始 274 个 Python 文件保持不变。当前范围、明确差异及
尚未集成的能力见 [迁移状态](CURRENT_MIGRATION.md) 和 [完整清单](MIGRATION_INVENTORY.md)；
收尾任务状态见 [MIGRATION_TASKS.md](MIGRATION_TASKS.md)，结果入口见
[最终验收索引](FINAL_ACCEPTANCE.md)。

## 迁移工程导览

从目录和模块组成开始，再通过同一 ReLU YAML 对照 Python 与 SV 的参数绑定、
硬件展开、程序装载和结果验收：

- [GitHub 文字阅读版](docs/migration-guide.md)
- [HTML 阅读版](docs/migration-guide.html)：下载后用浏览器打开，支持完整文件索引搜索和控制字交互。

文件清单为文档整理时的工作树快照，具体版本和未提交内容的边界见文档开头。

## 开始使用

Linux x86_64 需要 C++20 编译器、make、Perl、Python 3、curl、tar 和 unzip。

```bash
python3 sv/scripts/install_toolchain.py
source sv/build/toolchain/env.sh
make -C sv current
python3 sv/scripts/regression.py --list
python3 sv/scripts/regression.py --shard core
```

完整回归：`make -C sv regression`。本地和 CI 共用 14 组、49 个目标的清单，包含
原生数学测试、冻结 Python 周期兼容、负例、实际综合网表和历史基线。工具版本、
资源要求与结果位置见 [REGRESSION.md](REGRESSION.md)。完整 Mesh 网表检查建议独占
16 GiB 内存；不要把小组件的运行资源估计用于整个阵列。

上传的 ReLU YAML 可直接运行：

```bash
bash sv/tests/current/run_relu_yaml.sh sv/examples/yaml/relu_neura_pass.yaml
```

输入、32 个结果的回读、前端支持范围和内存时序限制见 [YAML_RELU.md](YAML_RELU.md)。

## 可配置硬件入口

| 入口 | 用途 |
|---|---|
| `rtl/tile/cgra_pe.sv` | **单个参数化 PE**；VARIANT=0/1/2 为 Base／Context／Streaming；可配置位宽、存储深度、有序 FU 列表 |
| `rtl/cgra/cgra_system.sv` | 参数化单 CGRA、边界连接、Controller、SPM 及可选外设 |
| `rtl/cgra/cgra_multi.sv` | 同构多 CGRA Mesh／Ring |
| `rtl/cgra/cgra_multi_template.sv` | 静态异构阵列形状、逐 Tile FU 配置与定向边界连接 |
| `rtl/cgra/cgra_2x2.sv` | 历史兼容入口；不是当前工程唯一顶层 |

`cgra_pe` 中 COLS／ROWS 等参数描述所属系统的地址和包格式，不会额外生成 2×2 PE。
Base／Context 支持 4 或 8 个物理端口，Streaming 为 8 个。详细公共接口、FU 接线和
保留的变体语义见 [PE_INTERFACES.md](PE_INTERFACES.md)。参数化不等于任意组合已通过验证。

[参数对应与验收范围](PARAMETERIZATION.md) 逐项区分 Python 构造参数、SV 参数和配置工具入口。
[跨架构运行结果](tests/parameterization/RESULTS.md) 记录固定 RTL、同一架构不同程序、
同一数学函数不同架构的运行及原 Python 对照；未通过项和接口缺口独立保留。

架构 JSON 生成静态参数和绑定；程序 JSON 生成控制包、常量、预加载和带 barrier 的
主机命令。它们不包含通用 DFG 映射器：

```bash
python3 -I -S sv/tools/cgra_config.py sv/examples/config/system.json --check
python3 -I -S sv/tools/cgra_config.py sv/examples/config/heterogeneous.json --output work/my-cgra
```

输入格式和已测试参数点见 [CONFIGURATION_TOOL.md](CONFIGURATION_TOOL.md) 与
[PROGRAM_TOOL.md](PROGRAM_TOOL.md)。

## 验收与独立交付

- [KERNEL_BOUNDARIES.md](KERNEL_BOUNDARIES.md)：AXPY、GEMM、GEMV 的独立数学回读、存储次数及完成顺序；区分原程序缺陷和修复配置。
- [SYSTEM_ACCEPTANCE.md](SYSTEM_ACCEPTANCE.md)：同构 16／64 PE、异构 21 PE，以及选定 Mesh／Ring 的完整实际综合网表。
- [MIGRATION_INVENTORY.md](MIGRATION_INVENTORY.md)：274 文件、99 个原始 opcode、4 个原生扩展和 59 个命令的范围及可达性。
- [STANDALONE.md](STANDALONE.md)：可校验、可重复生成的工程包，以及不含原 Python／Git 历史的干净构建。
- [DEPENDENCIES.md](DEPENDENCIES.md)：来源和许可；HardFloat 等有独立声明，MAC 相关源代码不能仅按项目 BSD 许可处理。

冻结参考与历史报告保留其生成时点和源码哈希。原 `phase2/3/4` 契约使用固定历史源码
运行，例如 `bash sv/scripts/run_baseline.sh phase3`；当前功能使用 `current-*`／`native-*`
入口。不要用历史 opcode 或已知错误的翻译结果要求原生默认模式逐位一致。

未重新运行全部原 Python 测试，未宣称任意参数的形式等价或 FPGA／ASIC 时序、面积达标。
独立 LoopController 的整机路由、可扩展存储的远程接口、通用映射编译器等后续范围见
迁移状态中的明确边界。
