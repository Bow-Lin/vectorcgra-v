# 在原生 SV 上运行映射好的 ReLU YAML

`examples/yaml/relu_neura_pass.yaml` 保留上传文件的原始字节，SHA256 为
`1d64eca29eb6e95825e7493c2d082398d5689a7f6a0e3bf08049a1b71dc848ca`。
它与原项目 `validation/test/relu.yaml` 只有末尾换行差异。这里直接读取 YAML，
生成主机配置并运行 `cgra_system`，不 import 原 Python RTL、ScriptFactory 或 PyMTL，
不在运行入口读取冻结 `program.hex`／周期轨迹。没有改动原 YAML、原 Python 或硬件 RTL。

## 运行

需要 Python 3、PyYAML 和项目固定的原生 Verilator／C++ 工具链。PyYAML 是此 YAML
入口的额外依赖；原有 JSON 配置／程序工具仍然只用标准库。

```bash
# 在仓库根目录，启用已安装的原生工具链。
source sv/build/toolchain/env.sh
# 未安装 PyYAML 时，在自己的 Python 环境执行：python3 -m pip install PyYAML
bash sv/tests/current/run_relu_yaml.sh sv/examples/yaml/relu_neura_pass.yaml
```

也可传入任意位置的同格式 YAML。第二个参数指定**尚不存在**的输出目录，第三个参数
可提供 JSON 数组，内容必须为 32 个有符号 int32；默认输入为 `[-16, -15, ..., 15]`。

```bash
bash sv/tests/current/run_relu_yaml.sh /path/to/relu_neura_pass.yaml work/relu-run
bash sv/tests/current/run_relu_yaml.sh /path/to/relu_neura_pass.yaml work/relu-custom input.json
```

首次运行编译原生 4×4 CGRA，随后按 RTL、参数、bench、脚本及工具版本的指纹复用构建。
每次都重新解析指定 YAML；输出目录已存在时拒绝覆盖。runner 执行正常节奏和主机
背压／输入间隔两种运行，错误结果、提前返回、额外写入或超时都会导致非零退出。

输出目录包括：

| 文件 | 用途 |
|---|---|
| `config.json`、`verilator.args` | 单 CGRA、4×4 Base PE、32 位、II=5、总控制步数 170、组合内存、所有 legacy 开关为零 |
| `program.json`、`program.hex` | 32 个预加载包和从 YAML 生成的 125 个配置／启动包 |
| `control.hex`、`constants.hex`、`preload.hex`、`index.json` | 控制字、常量、内存输入及来源索引 |
| `input.json`、`expected.hex`、`stores.txt`、`return.hex` | 输入、独立 `max(x,0)` 期望、每地址一次写入、返回包期望 |
| `results-normal.csv`、`results-backpressure.csv` | SV 通过主机接口实际读回的 32 个值，与独立期望并列 |
| `normal.log`、`backpressure.log` | 仿真结果及周期数；成功需要 `NATIVE_STORE_COUNTS_PASS` 和 `NATIVE_KERNEL_MATH_PASS` |
| `manifest.json`、`build-stamp.json` | YAML／工具／生成文件 SHA，以及硬件构建的源码、参数和工具版本 |

CSV 中值是 32 位十六进制。默认输入的输出是 17 个零，然后 `1, 2, ..., 15`。
失败运行可能留下部分 CSV；只有 runner 最后报告 `RELU_YAML_PASS` 才代表两次运行均通过。

## 前端范围

`tools/cgra_yaml.py` 是已映射标量指令的翻译器，不重新做布局或调度。它接受
`array_config` 的行列、II、core、单一 `entry0`、`index_per_ii`、operation 和 operand。
支持四方向端口、RED 标量通道、四组各 8 个寄存器 `$0..$31`、十进制 `#立即数`；
寄存器读写冲突、多个 FU 操作占用同一步、重复键、未知字段或不支持的 opcode 会报错。
YAML 仅用安全加载器读取，不执行附带代码或指令。

本次支持 `DATA_MOV`、`ADD`、`GEP`（两个操作数、字地址加法）、`ICMP_EQ`、
`ICMP_SGE`、`NOT`、`SEL`、`LOAD`、`STORE`、`GRANT_ONCE`、`GRANT_PREDICATE`、
`PHI_START`、`RETURN_VOID`。立即数形式仅支持 ADD／GEP／EQ／SGE／GRANT_ONCE，
SGE 的立即数必须在右侧。保留 STORE 的 data/address 到硬件 address/data 的顺序转换、
常量使用顺序、空槽 NAH 和 invalid_iterations 对应的 FU／crossbar 预热配置。

只生成配置而不运行数学台架时：

```bash
python3 sv/tools/cgra_yaml.py --yaml sv/examples/yaml/relu_neura_pass.yaml \
  --total-steps 170 --output work/relu-config
```

前端可表示 2…4 行／列的这类四端口静态映射，但此次整机验收仅覆盖所附
4×4、II=5、32 元素的 ReLU。运行台架固定使用这个数学契约；修改循环上界、输入尺寸、
内存布局或算法时，不能继续把它当成匹配的测试。没有承诺任意 YAML／DFG 兼容。

## 验证与已知限制

```bash
make -C sv native-yaml-relu
```

8 组前端单元检查包括与原 Python 的 125 个配置包逐字段对照，以及 schema／资源冲突
负例。整机使用默认、正负边界（含 INT_MIN／INT_MAX）、固定种子随机和全零四组输入，
每组正常／背压运行，共 **8 次数学验收、256 个读回值**。每次检查 32 次实际写入，
并在收到完成包时检查全部写入已经握手完成；不靠额外 drain 延时掩盖提前返回。

**这份映射只在组合内存模式下通过本次验收。** 它由 core9 返回，而 STORE 在 core1。
切换 `MEM_COMBINATIONAL=0` 后，默认输入在 cycle359 返回时只有 31／32 次写入完成。
这是原映射对内存时序的限制；本次未重排映射、改写返回路径或修改 RTL。
诊断变量 `RELU_MEMORY=0` 可复现，runner 会失败，不会把提前返回当作通过。

另外四个负向检查分别注入错误数学期望、永久背压、过多期望写入，以及把 YAML 的
SGE 改成 EQ；最后一个证明实际运行取决于传入 YAML。连同寄存内存反例，共 5 次负检。
本地记录见 [yaml-relu.json](results/yaml-relu.json)；日志和逐项输入／读回位于其列出的
`build/current/yaml-relu/regression-*` 目录。该入口已加入 `native-kernels` 回归组，
此次局部验收不代表完整 49 目标回归或远端 CI 已经运行。
