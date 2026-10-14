# 原 Python → 原生 SystemVerilog 补测结果

本轮 191 个静态测试组合均已逐项处理：**161 项通过、25 项严格周期对照不一致、
5 项受阻或未完成验收**。失败后继续执行其余用例，并重试了未通过项。
尚未达到“全部通过”的提交条件，**没有提交或推送**。

本轮只新增验证代码、冻结激励和结果记录；未修改原 Python、原生 RTL 或原程序。
原生 RTL 对应提交 `502f7ff26930b11f090195cc8094258d3090ea03`；Python 参考目标
为 `cd7aad878915e389cecf8cc01ff6987d156bd019`，原始迁移基线仍为 `ac96a7af`。
已核对固定目标记录的 274 个 Python 文件，全部保持不变。

## 统计口径

| 分组 | 静态组合 | 通过 | 周期对照不一致 | 其他未通过 |
| --- | ---: | ---: | ---: | ---: |
| 寄存器、控制状态、PE | 24 | 23 | 1 | 0 |
| FU、FlexibleFu、向量、浮点、组合与 MAC | 86 | 79 | 7 | 0 |
| Controller、内存、DMA、im2col、NoC、RF | 33 | 16 | 17 | 0 |
| CGRA、FIR、Context、Streaming、多 CGRA、整机 DMA | 45 | 43 | 0 | 2 |
| 原 GEMM、GEMV、SPMV YAML | 3 | 0 | 0 | 3 |
| **合计** | **191** | **161** | **25** | **5** |

161 项通过中，113 项比较全部输出的逐采样值，47 项检查原激励对应的完整事务、
结果和有界结束，1 项仅对应原 tapeout 测试的展开／编译检查。因此有行为验证
结论的是 **160 项**。编译检查的 ID 为 153，不能当作内核计算通过。

Hypothesis 的一个入口采集了 50 个独立 DUT 实例；它们都进行了 SV 重放，
但在 191 项中只计为一个静态入口，不重复增加通过数。冻结数据共 189 个用例、
237 个 DUT 轨迹；GEMM/GEMV 的两项沿用已经固定的未完成参考证据。

本清单覆盖之前盘点中选定的补测范围，并非整个 Python 仓库的全部测试，
也不证明任意参数或任意背压组合等价。

## 五项仍不能验收的用例

| ID | 原用例 | 当前结果与原因 |
| --- | --- | --- |
| 3 | FIR 2×2，无控制环、寄存内存 | 原测试在初始化后结束，没有完整 FIR 结果检查；原生 `cgra_system` 也缺少相应控制环旁路接口。记录为 `unsupported_architecture`。 |
| 10 | GEMM YAML | 原固定参考只有 2258 周期，未完整结束；历史采集因 30 分钟墙钟时限停止，不能据此认定死锁。记录为 `reference_incomplete`。 |
| 11 | GEMV YAML | 同上，原固定参考只有 2689 周期。记录为 `reference_incomplete`。 |
| 12 | SPMV YAML | 重试仍在原配置生成阶段报 `KeyError('ICMP_ULT')`，尚未创建 DUT。记录为 `python_failed`。 |
| 166 | Ring `test_homo_1x4` | 原函数只等配置源发送完就返回，未检查已有的完成 sink；补充完成检查后，Python 和 SV 均未观察到所需完成消息。 |

GEMM/GEMV 本轮复核了原有证据，**没有重新运行长时间的原 Python 全程序**。
这两项原程序的完整结束与结果验证仍是明确缺口。

Ring 原函数自身仍然通过，结果单独保留为 `original_function_status=passed`。
本轮未改其源文件，而是在返回后继续观察 500 个 Python 周期，并检查它本来就
声明的完成 sink；这项新增检查超时。SV 接收了全部 28 个 CPU 包，但完成包
为 0/1，在 5320 个周期的限制下超时。因此这里的 `python_failed` 指补充检查
失败，不能表述成“原 pytest 断言失败”，也不能仅凭两边同样超时证明迁移正确。

## 25 项严格周期差异

这些差异在原生默认参数下仍复现。诊断结果说明差异来源，**没有把兼容模式的
通过覆盖原生验收结果**。其中浮点数值解释、除法握手和仲裁背压差异具有功能
意义，不能笼统归类为“只是时间不同”。

| ID | 范围 | 观察到的差异 | 单独诊断 |
| --- | --- | --- | --- |
| 32 | Controller `test_simple` | 复位 ready 与无效输出消息不同 | 排除复位及无效输出消息后通过 |
| 39 | FlexibleFu prologue | 复位时 `recv_opt.rdy` 不同 | 同上，通过 |
| 42、43 | 浮点加、乘 | 原参考的浮点字段解释与原生 IEEE 格式不同，有效输出数值也不同 | 显式浮点历史兼容参数下通过；另跑 IEEE 数学检查通过 |
| 72 | ExclusiveDiv | 无效周期输出 payload 不同 | 有效周期诊断及历史兼容模式均通过 |
| 95 | InclusiveDiv | 原生带结果队列的流水线与原参考的接收／返回时序不同 | 历史兼容模式通过；原生 latency=4 独立边界检查通过 |
| 122 | VectorAllReduce | 空闲控制 ready 与无效 payload 不同 | 历史兼容模式通过 |
| 123 | VectorMulCombo | 复位／空闲 ready 门控不同 | 历史兼容模式通过 |
| 128 | ConstQueue | 复位时原生 `send_const.val=0`，原参考为 1 | 排除复位及无效消息后通过 |
| 134、135 | DataMemController，含 DMA 端口 | 复位、请求配对 ready、缓冲及无效输出行为不同 | 显式内存及 NoC 历史兼容参数下通过 |
| 137–143 | DmaEngine 的 7 组参数 | 复位时原生 `dma_cmd.rdy=0`，原参考为 1 | 排除复位及无效消息后全部通过 |
| 175–181 | StaticSwitch 的 7 组参数／函数 | 原生在阻塞时保持选择、在传输后推进优先级；原参考按周期轮转，空闲转发行为也不同 | 历史兼容模式全部通过，包含原断言涉及的 encoder、grants 和优先级状态 |

这里“排除复位及无效消息”对应 `--active`：仍比较所有非复位周期的 valid、
ready，只在消息无效时忽略 payload。它是定位方法，不能代替系统背压和
有界完成验证。`--compat` 只显式启用模块已有的历史语义开关。

相关既有契约见 `sv/ARITHMETIC_BOUNDARIES.md`、`sv/VECTOR_ARITHMETIC_API.md`、
`sv/VECTOR_REDUCE_API.md`、`sv/NOC_HANDSHAKES.md`、`sv/MEMORY_BOUNDARIES.md`、
`sv/STATIC_MEMORY_API.md` 和 `sv/CURRENT_MIGRATION_HISTORY.md`。这些语义调整
不是本轮为了让测试通过而引入的。

## 已补齐的主要验证

- 寄存器 bank／cluster 的 8 个原函数，包括 token、双路径错拍和 skid buffer；
  PE 的 7 个函数，包括多周期除法、路由优先级和同寄存器累加。
- FIR 2×2 组合／寄存内存、FIR + LoopCounter 整机、FIR 4×4 的 6 个原场景，
  以及 `CgraRTL_test.py` 的 7 个同构／异构／vector／systolic 用例。
- Context 双任务的 2 个场景、Streaming 的 2 种内存模式、Template 和
  VerifAssert 的原程序与断言。
- im2col 的 5 个组件函数，以及 2 个 im2col → 3×3 systolic 完整计算场景。
- 集成 DMA 的 4 个 128／256 位 mvin／mvout 场景：保留原内部 SPM 初始内容，
  检查最终内存和完成通知；另用错误内存期望验证断言确实生效。
- fused／migrated 两个原任务场景，多 CGRA 的 scalar／vector FIR、global reduce、
  模板异构场景，以及 16 个 CGRA、64 个 PE 的 systolic 组合／寄存内存场景。
- FU 原静态输入和期望、组合 FU、MAC、Hypothesis 生成实例；Controller、内存、
  DMA 和 NoC 的未通过项按上表保留，未因系统级测试通过而忽略。

逐项文件、函数、参数和结果见下方清单与 `results.json`。

## 验证机制与附加检查

原测试采集保留原 Source／Sink、参数和断言，原生重放只编译
`sv/filelists/native.f`，没有用 PyMTL 生成的 Verilog 替换 SV DUT。
普通组件逐采样对照；整机采用保持输入次序、最早发出周期及输出依赖的事务
重放，比较完整消息、数量、结果与超时。每项成功的行为检查还必须拒绝故意
篡改的期望，防止测试没有检查结果却报告通过。

附加运行以下已有原生测试，均通过，但不替代前述原程序失败或缺口：

| 检查 | 结果 |
| --- | --- |
| 修正程序的 GEMM／GEMV／SPMV 数学检查 | 分别 1657／405／964 周期完成，核对 16／4／32 个结果字；SPMV 另覆盖 nnz=0…8、背压及 5 种错误程序反例 |
| 原生数学检查 | SUB／PHI 32、64 位，IEEE 浮点 16／32／64 位加乘及错误期望反例通过 |
| InclusiveDiv，32 位、latency=4 | 原生 144 个样本、6158 次检查及历史轨迹对照通过 |
| 补测运行器检查 | 真实冻结用例重放、错误期望拒绝、轨迹损坏拒绝、失败参考不得通过、漏测不得全通过、可移植日志和诊断结果隔离均通过 |

最终核对：274 个原文件 SHA256 一致；449 份原生运行／反例日志哈希一致；
236 个原生重放的实例参数与采集清单一致；48 份整机事务清单重新生成后无差异。
本轮没有残留 `not_run`、`running`、`captured`、适配失败或编译失败状态。

## 文件和复现

- `cases.json`：191 项原测试及静态参数清单。
- `fixtures/`：冻结原参考状态、参数、端口、压缩激励及来源哈希。
- `results.json`：仅原生验收的完整结果；`all_passed=false`。
- `diagnostics.json`：25 个差异对应的 26 次单独诊断，不能计入原生通过数。
- `additional_checks.json`：附加数学、内核和运行器检查。
- `evidence/`：便于复核的原生、诊断及附加检查日志；运行日志路径相对结果文件。
  编译日志的原始工作目录路径仅作为运行来源记录，重建可得到新日志。

配置仓库规定的 native Verilator 5.029 后，在仓库根目录重放：

```sh
python3 sv/tests/original/run.py --replay-only --transactions \
  --output work/original-tests
python3 sv/tests/original/report.py --root work/original-tests \
  --output work/original-tests/results.json \
  --evidence-dir work/original-tests/evidence
```

目前命令应返回非零，因为保留了真实未通过项。后续需要逐项决定原生语义差异
的验收要求、补齐或明确无控制环架构范围，并完成三项原矩阵程序及 Ring 完成
条件的处理；在这些问题解决前不能宣布“全部原用例迁移通过”。

## 逐项清单

ID 与 `cases.json` 一致；参数完整值保存在 `results.json`。表中“通过”只代表
上文规定的检查范围；ID 153 单独标明编译检查。

| ID | 原文件与函数 | 静态参数 | 结果 |
| ---: | --- | --- | --- |
| 0 | `cgra/test/CgraRTL_fir_2x2_loop_counter_test.py::test_homogeneous_2x2_fir_with_loop_counter_combinational_mem_access_return` | `{}` | 通过 |
| 1 | `cgra/test/CgraRTL_fir_2x2_test.py::test_homogeneous_2x2_fir_combinational_mem_access_return` | `{}` | 通过 |
| 2 | `cgra/test/CgraRTL_fir_2x2_test.py::test_homogeneous_2x2_fir_non_combinational_mem_access_return` | `{}` | 通过 |
| 3 | `cgra/test/CgraRTL_fir_2x2_test.py::test_homogeneous_2x2_fir_non_combinational_mem_access_no_ctrl_ring` | `{}` | 架构缺口 |
| 4 | `cgra/test/CgraRTL_fir_test.py::test_homogeneous_4x4_fir_combinational_mem_access_terminate` | `{}` | 通过 |
| 5 | `cgra/test/CgraRTL_fir_test.py::test_homogeneous_4x4_fir_multi_cycle_mem_access_terminate` | `{}` | 通过 |
| 6 | `cgra/test/CgraRTL_fir_test.py::test_homogeneous_4x4_fir_combinational_mem_access_return` | `{}` | 通过 |
| 7 | `cgra/test/CgraRTL_fir_test.py::test_homogeneous_4x4_fir_multi_cycle_mem_access_return` | `{}` | 通过 |
| 8 | `cgra/test/CgraRTL_fir_test.py::test_homogeneous_4x4_fir_combinational_mem_access_vector_terminate` | `{}` | 通过 |
| 9 | `cgra/test/CgraRTL_fir_test.py::test_homogeneous_4x4_fir_combinational_mem_access_vector_return` | `{}` | 通过 |
| 10 | `cgra/test/CgraRTL_gemm_test_from_yaml.py::test_homogeneous_4x4_gemm_combinational_mem_access` | `{}` | 参考未完整结束 |
| 11 | `cgra/test/CgraRTL_gemv_test_from_yaml.py::test_homogeneous_4x4_gemv_combinational_mem_access` | `{}` | 参考未完整结束 |
| 12 | `cgra/test/CgraRTL_spmv_test_from_yaml.py::test_homogeneous_4x4_spmv_combinational_mem_access_return` | `{}` | 参考／补充检查失败 |
| 13 | `cgra/test/CgraRTL_test.py::test_homogeneous_2x2` | `{}` | 通过 |
| 14 | `cgra/test/CgraRTL_test.py::test_homogeneous_2x2_ctrl_count_2` | `{}` | 通过 |
| 15 | `cgra/test/CgraRTL_test.py::test_heterogeneous_king_mesh_2x2` | `{}` | 通过 |
| 16 | `cgra/test/CgraRTL_test.py::test_heterogeneous_with_loop_control` | `{}` | 通过 |
| 17 | `cgra/test/CgraRTL_test.py::test_vector_king_mesh_2x2` | `{}` | 通过 |
| 18 | `cgra/test/CgraRTL_test.py::test_vector_mesh_4x4` | `{}` | 通过 |
| 19 | `cgra/test/CgraRTL_test.py::test_systolic_3x3` | `{}` | 通过 |
| 20 | `cgra/test/CgraTemplateRTL_test.py::test_cgra_universal` | `{}` | 通过 |
| 21 | `cgra/test/CgraVerifAssert_test.py::test_homogeneous_2x2_fir_combinational_mem_access_return` | `{}` | 通过 |
| 22 | `cgra/test/CgraWithContextSwitchRTL_test.py::test_sim_fir_combinational_mem_access_return_two_tasks` | `{}` | 通过 |
| 23 | `cgra/test/CgraWithContextSwitchRTL_test.py::test_sim_fir_multi_cycle_mem_access_return_two_tasks` | `{}` | 通过 |
| 24 | `cgra/test/CgraWithStreamingLoadRTL_test.py::test_streaming_ld_combinational_mem_access` | `{}` | 通过 |
| 25 | `cgra/test/CgraWithStreamingLoadRTL_test.py::test_streaming_ld_non_combinational_mem_access` | `{}` | 通过 |
| 26 | `cgra/test/Im2colCgraE2E_test.py::test_im2col_to_systolic_3x3` | `{}` | 通过 |
| 27 | `cgra/test/Im2colCgraE2E_test.py::test_im2col_conv1d_to_systolic_3x3` | `{}` | 通过 |
| 28 | `cgra/test/IntegratedCgraWithDmaRTL_test.py::test_cgra_dma_mvin_to_local_spm` | `{"dram_data_nbits": 128}` | 通过 |
| 29 | `cgra/test/IntegratedCgraWithDmaRTL_test.py::test_cgra_dma_mvin_to_local_spm` | `{"dram_data_nbits": 256}` | 通过 |
| 30 | `cgra/test/IntegratedCgraWithDmaRTL_test.py::test_cgra_dma_mvout_from_local_spm` | `{"dram_data_nbits": 128}` | 通过 |
| 31 | `cgra/test/IntegratedCgraWithDmaRTL_test.py::test_cgra_dma_mvout_from_local_spm` | `{"dram_data_nbits": 256}` | 通过 |
| 32 | `controller/test/ControllerRTL_test.py::test_simple` | `{}` | 周期对照不一致 |
| 33 | `controller/test/GlobalReduceUnitRTL_test.py::test_simple` | `{}` | 通过 |
| 34 | `fu/double/test/TwoPrlComboRTL_test.py::test_mul_alu` | `{}` | 通过 |
| 35 | `fu/double/test/TwoSeqComboRTL_test.py::test_mul_alu` | `{}` | 通过 |
| 36 | `fu/double/test/TwoSeqComboRTL_test.py::test_mul_shifter` | `{}` | 通过 |
| 37 | `fu/flexible/test/FlexibleFuRTL_hypothesis_test.py::test_hypothesis` | `{}` | 通过 |
| 38 | `fu/flexible/test/FlexibleFuRTL_test.py::test_flexible_alu` | `{}` | 通过 |
| 39 | `fu/flexible/test/FlexibleFuRTL_test.py::test_flexible_fu_prologue_advances_without_const` | `{}` | 周期对照不一致 |
| 40 | `fu/flexible/test/FlexibleFuRTL_test.py::test_flexible_mul` | `{}` | 通过 |
| 41 | `fu/flexible/test/FlexibleFuRTL_test.py::test_flexible_universal` | `{}` | 通过 |
| 42 | `fu/float/test/FpAddRTL_test.py::test_add_basic` | `{}` | 周期对照不一致 |
| 43 | `fu/float/test/FpMulRTL_test.py::test_mul` | `{}` | 周期对照不一致 |
| 44 | `fu/fused_alu_fixedp/test/AluGenMacRTL_test.py::test_add_basic` | `{}` | 通过 |
| 45 | `fu/fused_alu_fixedp/test/AluGenMacWrapperRTL_test.py::test_add_ones` | `{}` | 通过 |
| 46 | `fu/fused_alu_fixedp/test/AluGenMacWrapperRTL_test.py::test_sub` | `{}` | 通过 |
| 47 | `fu/fused_alu_fixedp/test/AluGenMacWrapperRTL_test.py::test_gte` | `{}` | 通过 |
| 48 | `fu/fused_alu_fixedp/test/AluGenMacWrapperRTL_test.py::test_mul` | `{}` | 通过 |
| 49 | `fu/fused_alu_fixedp/test/AluGenMacWrapperRTL_test.py::test_mac` | `{}` | 通过 |
| 50 | `fu/others/test/Im2colEngineRTL_test.py::test_engine_4x4_k2_s1` | `{}` | 通过 |
| 51 | `fu/others/test/Im2colEngineRTL_test.py::test_engine_4x4_k2_s2` | `{}` | 通过 |
| 52 | `fu/others/test/Im2colEngineRTL_test.py::test_engine_5x5_k3_s1` | `{}` | 通过 |
| 53 | `fu/others/test/Im2colEngineRTL_test.py::test_engine_smoke_matches_e2e_layout` | `{}` | 通过 |
| 54 | `fu/others/test/Im2colEngineRTL_test.py::test_engine_nonzero_dst_sram_base` | `{}` | 通过 |
| 55 | `fu/quadra/test/FourIncCmpNotGrantRTL_test.py::test_four` | `{}` | 通过 |
| 56 | `fu/single/test/AdderRTL_test.py::test_alu` | `{}` | 通过 |
| 57 | `fu/single/test/AluRTL_test.py::test_add_sub` | `{}` | 通过 |
| 58 | `fu/single/test/AluRTL_test.py::test_logic` | `{}` | 通过 |
| 59 | `fu/single/test/AluRTL_test.py::test_shifter` | `{}` | 通过 |
| 60 | `fu/single/test/AluRTL_test.py::test_mul` | `{}` | 通过 |
| 61 | `fu/single/test/CompRTL_test.py::test_Comp` | `{}` | 通过 |
| 62 | `fu/single/test/CompRTL_test.py::test_Comp_const` | `{}` | 通过 |
| 63 | `fu/single/test/CompRTL_test.py::test_Comp_const_terminal_predicate` | `{}` | 通过 |
| 64 | `fu/single/test/CompRTL_test.py::test_Comp_const_predicate_depends_on_const` | `{}` | 通过 |
| 65 | `fu/single/test/ConstRTL_test.py::test_const` | `{}` | 通过 |
| 66 | `fu/single/test/DivRTL_test.py::test_div0` | `{"input_a": 5, "input_b": 2}` | 通过 |
| 67 | `fu/single/test/DivRTL_test.py::test_div0` | `{"input_a": 5, "input_b": 3}` | 通过 |
| 68 | `fu/single/test/DivRTL_test.py::test_div0` | `{"input_a": 6, "input_b": 2}` | 通过 |
| 69 | `fu/single/test/DivRTL_test.py::test_div0` | `{"input_a": 6, "input_b": 3}` | 通过 |
| 70 | `fu/single/test/DivRTL_test.py::test_div0` | `{"input_a": 7, "input_b": 2}` | 通过 |
| 71 | `fu/single/test/DivRTL_test.py::test_div0` | `{"input_a": 7, "input_b": 3}` | 通过 |
| 72 | `fu/single/test/ExclusiveDivRTL_test.py::test_mul` | `{}` | 周期对照不一致 |
| 73 | `fu/single/test/ExtractPredicateRTL_test.py::test_extract_predicate_basic` | `{}` | 通过 |
| 74 | `fu/single/test/ExtractPredicateRTL_test.py::test_extract_predicate_for_loop_termination` | `{}` | 通过 |
| 75 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 0, "index": 0}` | 通过 |
| 76 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 0, "index": 4}` | 通过 |
| 77 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 0, "index": 8}` | 通过 |
| 78 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 0, "index": 12}` | 通过 |
| 79 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 0, "index": 16}` | 通过 |
| 80 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 40, "index": 0}` | 通过 |
| 81 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 40, "index": 4}` | 通过 |
| 82 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 40, "index": 8}` | 通过 |
| 83 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 40, "index": 12}` | 通过 |
| 84 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 40, "index": 16}` | 通过 |
| 85 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 80, "index": 0}` | 通过 |
| 86 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 80, "index": 4}` | 通过 |
| 87 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 80, "index": 8}` | 通过 |
| 88 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 80, "index": 12}` | 通过 |
| 89 | `fu/single/test/GepRTL_test.py::test_gep_1d` | `{"base": 80, "index": 16}` | 通过 |
| 90 | `fu/single/test/GepRTL_test.py::test_gep_1d_const` | `{}` | 通过 |
| 91 | `fu/single/test/GepRTL_test.py::test_gep_2d` | `{}` | 通过 |
| 92 | `fu/single/test/GepRTL_test.py::test_gep_2d_const` | `{}` | 通过 |
| 93 | `fu/single/test/GepRTL_test.py::test_gep_predicate` | `{}` | 通过 |
| 94 | `fu/single/test/GrantRTL_test.py::test_grant` | `{}` | 通过 |
| 95 | `fu/single/test/InclusiveDivRTL_test.py::test_mul` | `{}` | 周期对照不一致 |
| 96 | `fu/single/test/LoopControlRTL_test.py::test_loop_control_basic` | `{}` | 通过 |
| 97 | `fu/single/test/LoopControlRTL_test.py::test_loop_control_step` | `{}` | 通过 |
| 98 | `fu/single/test/LoopControlRTL_test.py::test_loop_control_nested` | `{}` | 通过 |
| 99 | `fu/single/test/LoopCounterRTL_test.py::test_leaf_counter_basic` | `{}` | 通过 |
| 100 | `fu/single/test/LoopCounterRTL_test.py::test_loop_counter_with_step` | `{}` | 通过 |
| 101 | `fu/single/test/LoopCounterRTL_test.py::test_shadow_register_basic` | `{}` | 通过 |
| 102 | `fu/single/test/LoopCounterRTL_test.py::test_counter_reset` | `{}` | 通过 |
| 103 | `fu/single/test/MemUnitRTL_test.py::test_Mem` | `{}` | 通过 |
| 104 | `fu/single/test/MemUnitRTL_test.py::test_store_predicate` | `{"addr_pred": 0, "data_pred": 1}` | 通过 |
| 105 | `fu/single/test/MemUnitRTL_test.py::test_store_predicate` | `{"addr_pred": 1, "data_pred": 0}` | 通过 |
| 106 | `fu/single/test/MemUnitRTL_test.py::test_PseudoMem` | `{}` | 通过 |
| 107 | `fu/single/test/MulRTL_test.py::test_mul0` | `{"input_a": 3, "input_b": 2}` | 通过 |
| 108 | `fu/single/test/MulRTL_test.py::test_mul0` | `{"input_a": 3, "input_b": 3}` | 通过 |
| 109 | `fu/single/test/MulRTL_test.py::test_mul0` | `{"input_a": 4, "input_b": 2}` | 通过 |
| 110 | `fu/single/test/MulRTL_test.py::test_mul0` | `{"input_a": 4, "input_b": 3}` | 通过 |
| 111 | `fu/single/test/PhiRTL_test.py::test_Phi` | `{}` | 通过 |
| 112 | `fu/single/test/PhiRTL_test.py::test_Phi_start` | `{}` | 通过 |
| 113 | `fu/single/test/PhiRTL_test.py::test_Phi_const` | `{}` | 通过 |
| 114 | `fu/single/test/PhiRTL_test.py::test_Phi_vector` | `{}` | 通过 |
| 115 | `fu/single/test/RetRTL_test.py::test_Ret` | `{}` | 通过 |
| 116 | `fu/single/test/RetRTL_test.py::test_Ret_Void` | `{}` | 通过 |
| 117 | `fu/single/test/SelRTL_test.py::test_Select` | `{}` | 通过 |
| 118 | `fu/single/test/StreamingMemUnitRTL_test.py::test_streaming_load` | `{}` | 通过 |
| 119 | `fu/triple/test/ThreeMulAluShifterRTL_test.py::test_mul_alu_shifter` | `{}` | 通过 |
| 120 | `fu/vector/test/VectorAdderComboRTL_test.py::test_vector_adder_combo` | `{}` | 通过 |
| 121 | `fu/vector/test/VectorAdderRTL_test.py::test_vadder` | `{}` | 通过 |
| 122 | `fu/vector/test/VectorAllReduceRTL_test.py::test_vector_all_reduce` | `{}` | 周期对照不一致 |
| 123 | `fu/vector/test/VectorMulComboRTL_test.py::test_vector_mul_combo` | `{}` | 周期对照不一致 |
| 124 | `fu/vector/test/VectorMulRTL_test.py::test_vadder` | `{}` | 通过 |
| 125 | `mem/const/test/ConstQueueDynamicRTL_test.py::test_const_num_lt_mem` | `{}` | 通过 |
| 126 | `mem/const/test/ConstQueueDynamicRTL_test.py::test_const_num_gt_mem` | `{}` | 通过 |
| 127 | `mem/const/test/ConstQueueDynamicRTL_test.py::test_const_loop` | `{}` | 通过 |
| 128 | `mem/const/test/ConstQueueRTL_test.py::test_const_queue` | `{}` | 周期对照不一致 |
| 129 | `mem/ctrl/test/ContextSwitchRTL_test.py::test_pause_resume_iteration` | `{}` | 通过 |
| 130 | `mem/ctrl/test/ContextSwitchRTL_test.py::test_preserve_resume_accumulation` | `{}` | 通过 |
| 131 | `mem/ctrl/test/CtrlMemDynamicRTL_test.py::test_ctrl` | `{}` | 通过 |
| 132 | `mem/ctrl/test/CtrlMemDynamicRTL_test.py::test_ctrl_bound` | `{}` | 通过 |
| 133 | `mem/ctrl/test/CtrlMemDynamicRTL_test.py::test_return` | `{}` | 通过 |
| 134 | `mem/data/test/DataMemControllerRTL_dma_test.py::test_dma_ports_write_then_read` | `{}` | 周期对照不一致 |
| 135 | `mem/data/test/DataMemControllerRTL_test.py::test_mem_controller` | `{}` | 周期对照不一致 |
| 136 | `mem/data/test/DataMemWrapperRTL_test.py::test_const_queue` | `{}` | 通过 |
| 137 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvin_one_beat` | `{}` | 周期对照不一致 |
| 138 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvout_partial_beat` | `{}` | 周期对照不一致 |
| 139 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvout_full_beat` | `{}` | 周期对照不一致 |
| 140 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvin_configurable_partial_second_beat` | `{"dram_data_nbits": 96}` | 周期对照不一致 |
| 141 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvin_configurable_partial_second_beat` | `{"dram_data_nbits": 256}` | 周期对照不一致 |
| 142 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvout_configurable_partial_second_beat` | `{"dram_data_nbits": 96}` | 周期对照不一致 |
| 143 | `mem/dma/test/DmaEngineRTL_test.py::test_dma_mvout_configurable_partial_second_beat` | `{"dram_data_nbits": 256}` | 周期对照不一致 |
| 144 | `mem/register_cluster/test/RegisterBankRTL_test.py::test_reg_bank` | `{}` | 通过 |
| 145 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_bank` | `{}` | 通过 |
| 146 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_cluster_read_towards_routing_xbar` | `{}` | 通过 |
| 147 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_cluster_read_towards_both` | `{}` | 通过 |
| 148 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_cluster_read_towards_fu_no_xbar_output` | `{}` | 通过 |
| 149 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_cluster_token_not_overwritten` | `{}` | 通过 |
| 150 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_cluster_both_paths_skewed_acceptance` | `{}` | 通过 |
| 151 | `mem/register_cluster/test/RegisterClusterRTL_test.py::test_reg_cluster_write_skid_buffer` | `{}` | 通过 |
| 152 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_sim_homo_2x2_2x2` | `{}` | 通过 |
| 153 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_tapeout_2x2_2x2` | `{}` | 通过（仅编译） |
| 154 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_systolic_2x2_2x2` | `{}` | 通过 |
| 155 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_systolic_2x2_2x2_non_combinational_mem_access` | `{}` | 通过 |
| 156 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_systolic_4x4_2x2` | `{}` | 通过 |
| 157 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_fir_scalar` | `{}` | 通过 |
| 158 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_fir_scalar_2x2_2x2` | `{}` | 通过 |
| 159 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_fir_vector` | `{}` | 通过 |
| 160 | `multi_cgra/test/MeshMultiCgraRTL_test.py::test_multi_CGRA_fir_vector_global_reduce` | `{}` | 通过 |
| 161 | `multi_cgra/test/MeshMultiCgraTemplateRTL_test.py::test_mesh_multi_cgra_universal` | `{}` | 通过 |
| 162 | `multi_cgra/test/MeshMultiCgraTemplateRTL_test.py::test_simplified_multi_cgra` | `{}` | 通过 |
| 163 | `multi_cgra/test/MeshMultiCgraTemplateRTL_test.py::test_mesh_multi_hetero_cgra` | `{}` | 通过 |
| 164 | `multi_cgra/test/MultiCgraRTL_migration_test.py::test_multi_CGRA_fir_scalar_fused` | `{}` | 通过 |
| 165 | `multi_cgra/test/MultiCgraRTL_migration_test.py::test_multi_CGRA_fir_scalar_migrated` | `{}` | 通过 |
| 166 | `multi_cgra/test/RingMultiCgraRTL_test.py::test_homo_1x4` | `{}` | 参考／补充检查失败 |
| 167 | `multi_cgra/test/RingNetworkRTL_test.py::RingNetwork_Tests::test_cgra_data` | `{}` | 通过 |
| 168 | `noc/test/ChannelWithClearRTL_test.py::test_passthrough` | `{}` | 通过 |
| 169 | `noc/test/ChannelWithClearRTL_test.py::test_normal2_simple` | `{}` | 通过 |
| 170 | `noc/test/CrossbarRTL_test.py::test_crossbar` | `{}` | 通过 |
| 171 | `noc/test/CrossbarRTL_test.py::test_multi_cast` | `{}` | 通过 |
| 172 | `noc/test/LinkOrRTL_test.py::test_simple` | `{}` | 通过 |
| 173 | `noc/test/OrLinkRTL_test.py::test_simple` | `{}` | 通过 |
| 174 | `noc/test/SelectorRTL_test.py::test_simple` | `{}` | 通过 |
| 175 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_bits` | `{"num_inports": 2}` | 周期对照不一致 |
| 176 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_bits` | `{"num_inports": 3}` | 周期对照不一致 |
| 177 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_bits` | `{"num_inports": 5}` | 周期对照不一致 |
| 178 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_bits` | `{"num_inports": 6}` | 周期对照不一致 |
| 179 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_bits` | `{"num_inports": 8}` | 周期对照不一致 |
| 180 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_control_packet` | `{}` | 周期对照不一致 |
| 181 | `noc/test/StaticSwitchUnitRTL_test.py::test_static_switch_import` | `{}` | 周期对照不一致 |
| 182 | `rf/test/RegFile_test.py::test_RegFile` | `{}` | 通过 |
| 183 | `rf/test/RegisterRTL_test.py::test_simple` | `{}` | 通过 |
| 184 | `tile/test/TileRTL_test.py::test_tile_alu` | `{}` | 通过 |
| 185 | `tile/test/TileRTL_test.py::test_tile_multicycle_exclusive` | `{}` | 通过 |
| 186 | `tile/test/TileRTL_test.py::test_tile_multicycle_inclusive` | `{}` | 通过 |
| 187 | `tile/test/TileRTL_test.py::test_readReg_routing_priority` | `{}` | 通过 |
| 188 | `tile/test/TileRTL_test.py::test_prologue_nah` | `{}` | 通过 |
| 189 | `tile/test/TileRTL_test.py::test_tile_same_register_accumulate` | `{}` | 通过 |
| 190 | `tile/test/TileWithContextSwitchRTL_test.py::test_tile_alu` | `{}` | 通过 |
