# 原 Python 测试补测

`cases.json` 列出本轮待补的 191 个静态测试组合，保留原文件、函数、参数和
源码 SHA256。Hypothesis 的一个入口会产生多个独立 DUT 轨迹，不能把这些轨迹
重复计作静态参数组合。范围来自迁移覆盖盘点，并非整个 Python 仓库的所有测试。

本目录只增加验证。没有改 Python、RTL 或原程序以使测试通过。

以上描述对应初次补测的 `RESULTS.md`。后续处理另见 `FOLLOWUP.md`：
新增原生 `HAS_CTRL_RING=0` 构造参数，原 Python 与冻结原参考保持不变。

## 运行

先配置 native Verilator（仓库固定版本为 5.029），然后执行：

```sh
python3 sv/tests/original/run.py --replay-only --transactions \
  --output work/original-tests
```

普通组件逐采样比较全部输出；整机和 im2col 使用原测试实际接收的事务队列，
检查结果、顺序、数量及有界结束。`--group state_pe|fu|components|systems|matrix`
或 `--ids 0,1,2` 可选子集。不加 `--transactions` 可运行整机的严格周期诊断。
默认参数使用 native 实现，不隐式打开任何 Python 兼容开关。

每个用例写独立 `result.json`。一个失败不会阻止后续用例运行。
成功的输出检查还必须拒绝故意篡改的期望，防止台架空跑；原来只做翻译的
tapeout 用例单独标记 `elaboration_only`，仅验证 native 同参数实例的编译。

```sh
python3 sv/tests/original/report.py --root work/original-tests \
  --output work/original-tests/all-results.json
```

报告包含所有 191 项；未运行、参考失败、不完整、适配失败及 SV 不通过均保留，
均不能算全通过。`--active` 和 `--compat` 是单独的诊断，不能计入 native 验收。
`--active` 只屏蔽复位期间及无效输出消息的比较，仍比较 valid 和 ready；
它不是通用功能等价证明。`--compat` 只打开模块明确提供的历史语义参数。

## 来源与检查范围

`migration_tools/original_test_capture.py` 原样调用固定目标
`cd7aad878915e389cecf8cc01ff6987d156bd019` 的测试函数，保留原 Source/Sink、
断言、静态参数和 Hypothesis 生成的实例。采集前后检查 274 个原 Python 文件。
采集需要原 custom PyMTL 环境；native 重放只需标准 Python 和 Verilator。

```sh
python3 sv/tests/original/run.py --output work/original-capture \
  --python /path/to/pymtl-venv/bin/python \
  --reference-verilator /path/to/verilator-4.036 --capture-only
python3 sv/tests/original/freeze.py --root work/original-capture
```

原测试调用 Verilog placeholder 时仍使用它自己的实现，但测试对象的 SV 重放
只编译 `filelists/native.f`，不把 PyMTL 生成的 Verilog 接入 native DUT。

`original_test_profiles.py` 显式映射模块、参数、FU 清单和拓扑。原两操作数
控制记录映射到 native 四操作数布局时保持原字段并把新增槽位置零；不改 opcode、
数据、程序顺序或期望结果。模板架构的边界、内存端口和异构 FU 都从原实例导出。
StaticSwitch 还比较原测试断言的 encoder、grants 和优先级状态。

整机重放保持各输入流的顺序、最早发出周期及对已完成输出的依赖，输入保持到
握手。输出按通道检查完整消息，并保留原 sink 完成后的 ready 状态，避免改变
原程序的停止条件。这验证原激励及结果，不证明任意背压或任意参数组合。
`transactions.json` 给出每个端口实际验证的输入、输出数量。
DMA 原用例在时钟沿前断言的最终完成通知也计入期望观察；其直接写入的 SPM
初始内容从原实例采集并装入 native 台架。结束时逐字核对 SPM，另用错误内存
期望确认这些断言有效。因此 mvin/mvout 不会仅因端口握手结束就被标为通过。

冻结数据位于 `fixtures/`，包含原测试状态、端口/参数清单及压缩轨迹。
解压后校验轨迹 SHA256。失败的参考即使留下部分轨迹也不能产生通过结论。
编译缓存按台架、参数和预处理后的 native RTL 区分；更换工具链应使用新输出目录。

## 已知不能直接标为通过的情况

- 无控制环 FIR：原测试直接结束，没有完整 FIR 结果；native 系统也没有对应的
  控制环旁路 API，记录为 `unsupported_architecture`。
- GEMM/GEMV：保留原固定目标的 2258/2689 周期证据，但参考没有完整结束，
  记录为 `reference_incomplete`。修正程序的数学测试单独列出，不代替原程序通过。
- SPMV：原配置生成报 `KeyError: ICMP_ULT`，记录为 `python_failed`。
- Ring `test_homo_1x4`：原函数只等待配置源发送完，未等待其已有的完成 sink。
  本轮在不改源文件的情况下补上 500 周期完成检查；原函数结果和补充检查结果
  分开记录，并把原 sink 的期望完成消息交给 SV 检查，不能只重放配置就算通过。
- native 对复位握手、无效消息、除法流水线、浮点格式及背压仲裁的既有调整，
  可能使严格周期比较失败。兼容诊断用于解释差异，不能静默替换 native 结果。

本轮实际结果和不通过项见 `results.json`、`RESULTS.md`。存在未通过项时不提交。

`diagnostics.json` 单独保存有效周期／兼容模式的诊断；
`additional_checks.json` 保存独立数学、修正内核及运行器检查。
`report.py --evidence-dir <目录>` 会校验并复制运行日志，生成相对报告位置的路径。
`freeze.py` 在索引中记录 Python 目标、当前 RTL 提交及验证工具源码哈希。

后续的 `--contract` 仅用于已逐项核实的 11 个复位／无效数据用例：

```sh
python3 sv/tests/original/run.py --replay-only --contract \
  --ids 32,39,72,128,137,138,139,140,141,142,143 --output work/original-contract
```

与诊断性的 `--active` 不同，该模式仍比较复位周期，只将文档明确约定的
指定端口期望改为 0；其余握手逐位比较，valid=1 的数据始终比较。
每项还检查有效活动确实发生；prologue 用例应恰好消费一个控制且不产生数据。
错误握手期望及错误复位期望必须被拒绝。模式不适用于其他用例，不隐式开启 legacy。

14 个行为差异的独立原生检查由 `review_native.py --output <目录>` 执行，
不代替原始逐周期等价结论。`matrix_counterexamples.py` 复现 GEMM/GEMV 原配置、
去掉 token 保留修正及去掉 stride 修正的失败；运行前需构建当前 native kernel 台架。
`migration_tools/ring_completion_reference.py` 在原 Ring 架构上增加可完成的
远程读／计算／写／完成／回读程序。其参考标记为 supplemental，运行器不会
将它计入原用例全通过的判断；原 Ring 失败仍保留。
