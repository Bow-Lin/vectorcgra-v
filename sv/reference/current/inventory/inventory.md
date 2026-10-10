# Python → SV 完整映射清单

由 `migration_tools/inventory.py` 生成。每个源文件的 SHA 和全部类／函数／方法（含更新块）见同目录 `inventory.json`。
这是一份分类和实现位置清单，不是“274 个文件全部功能等价”或原 Python 测试通过率。证据链接保留各自批次；必须检查其参数、模式及源码 SHA。

## 文件

| Python 文件 | 类别 | 对应实现／工具 | 边界 |
|---|---|---|---|
| `.github/scripts/issue_to_pr_gemini.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `.github/scripts/issue_to_pr_openai.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `cgra/CgraFL.py` | reference_model |  | Functional/cycle-level software model; not an additional RTL implementation or exact migrated software API. |
| `cgra/CgraRTL.py` | rtl | `sv/rtl/cgra/cgra_system.sv` | Parameterized profile; variant/FU catalog and explicit topology tables replace Python class elaboration. |
| `cgra/CgraTemplateRTL.py` | rtl | `sv/rtl/cgra/cgra_system.sv` | Parameterized profile; variant/FU catalog and explicit topology tables replace Python class elaboration. |
| `cgra/CgraWithContextSwitchRTL.py` | rtl | `sv/rtl/cgra/cgra_system.sv` | Parameterized profile; variant/FU catalog and explicit topology tables replace Python class elaboration. |
| `cgra/CgraWithStreamingLoadRTL.py` | rtl | `sv/rtl/cgra/cgra_system.sv` | Parameterized profile; variant/FU catalog and explicit topology tables replace Python class elaboration. |
| `cgra/IntegratedCgraWithDmaRTL.py` | rtl | `sv/rtl/peripheral/cgra_integrated_dma.sv` | Fixed 32-bit SPM words; see DMA/im2col boundary contract. |
| `cgra/IntegratedIm2ColWithCgraRTL.py` | rtl | `sv/rtl/peripheral/cgra_integrated_im2col.sv` | Fixed 32-bit SPM words; see DMA/im2col boundary contract. |
| `cgra/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `cgra/test/CgraRTL_axpy_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_fir4x4_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_fir_2x2_loop_counter_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_fir_2x2_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_fir_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_gemm_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_gemv_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_histogram_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_relu4x4_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_sad_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_spmv_test_from_yaml.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraTemplateRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraVerifAssert_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraWithContextSwitchRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/CgraWithStreamingLoadRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/Im2colCgraE2E_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/IntegratedCgraWithDmaRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `cgra/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `controller/ControllerRTL.py` | rtl | `sv/rtl/controller/cgra_controller.sv` | Explicit native/legacy semantics; controller dispatch is a whitelist, not a universal catch-all. |
| `controller/GlobalReduceUnitRTL.py` | rtl | `sv/rtl/controller/cgra_global_reduce.sv` | Explicit native/legacy semantics; controller dispatch is a whitelist, not a universal catch-all. |
| `controller/LoopControllerRTL.py` | rtl | `sv/rtl/controller/cgra_loop_controller.sv` | Standalone only, no system route or general DAG. |
| `controller/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `controller/test/ControllerRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `controller/test/GlobalReduceUnitRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `controller/test/LoopControllerRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `controller/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/basic/FourCombo.py` | bounded_factory | `sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv` | Concrete shipped combinations implemented. Arbitrary Python FU class composition is not a standalone SV factory API; FU interface is 4 inputs / 2 outputs. |
| `fu/basic/Fu.py` | integrated | `sv/rtl/common/cgra_profile.svh`<br>`sv/rtl/common/cgra_fu_catalog.svh`<br>`sv/rtl/fu/tile_flexible_fu_configurable.sv` | Base interface/default signals are inlined in concrete FUs; no synthesizable Python base class API. |
| `fu/basic/ReduceMulUnit.py` | integrated | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` | Reduction arithmetic is inlined; generic standalone child-class API is not exported. |
| `fu/basic/SumUnit.py` | integrated | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` | Reduction arithmetic is inlined; generic standalone child-class API is not exported. |
| `fu/basic/ThreeCombo.py` | bounded_factory | `sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv` | Concrete shipped combinations implemented. Arbitrary Python FU class composition is not a standalone SV factory API; FU interface is 4 inputs / 2 outputs. |
| `fu/basic/TwoPrlCombo.py` | bounded_factory | `sv/rtl/fu/combo/tile_prl_mul_adder.sv` | Concrete shipped combinations implemented. Arbitrary Python FU class composition is not a standalone SV factory API; FU interface is 4 inputs / 2 outputs. |
| `fu/basic/TwoSeqCombo.py` | bounded_factory | `sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_shifter.sv` | Concrete shipped combinations implemented. Arbitrary Python FU class composition is not a standalone SV factory API; FU interface is 4 inputs / 2 outputs. |
| `fu/basic/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/double/PrlMulAdderRTL.py` | rtl | `sv/rtl/fu/combo/tile_prl_mul_adder.sv` |  |
| `fu/double/SeqMulAdderRTL.py` | rtl | `sv/rtl/fu/combo/tile_seq_mul_adder.sv` |  |
| `fu/double/SeqMulShifterRTL.py` | rtl | `sv/rtl/fu/combo/tile_seq_mul_shifter.sv` |  |
| `fu/double/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/double/test/TwoPrlComboRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/double/test/TwoSeqComboRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/double/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/flexible/FlexibleFuRTL.py` | rtl | `sv/rtl/fu/tile_flexible_fu_configurable.sv`<br>`sv/rtl/common/cgra_fu_catalog.svh` | Ordered catalog including NAH; fixed 4-input/2-output FU contract, not arbitrary Python class injection. |
| `fu/flexible/FuFL.py` | reference_model |  | Functional/cycle-level software model; not an additional RTL implementation or exact migrated software API. |
| `fu/flexible/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/flexible/test/FlexibleFuRTL_hypothesis_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/flexible/test/FlexibleFuRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/flexible/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/float/FpAddRTL.py` | rtl | `sv/rtl/fu/float/tile_fp_add.sv`<br>`sv/rtl/fu/float/tile_fp_fu.sv` | Native IEEE format/handshakes differ deliberately; FP_LEGACY_PYTHON is explicit compatibility. |
| `fu/float/FpMulRTL.py` | rtl | `sv/rtl/fu/float/tile_fp_mul.sv`<br>`sv/rtl/fu/float/tile_fp_fu.sv` | Native IEEE format/handshakes differ deliberately; FP_LEGACY_PYTHON is explicit compatibility. |
| `fu/float/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/float/test/FpAddRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/float/test/FpMulRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/float/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/fused_alu_fixedp/AluGenMacRTL.py` | rtl | `sv/rtl/fu/combo/cgra_alu_gen_mac.sv`<br>`sv/rtl/fu/combo/cgra_alu_gen_mac_core.sv` | Translated wrapper replaced with native core; vendor source retained with provenance. |
| `fu/fused_alu_fixedp/AluGenMacWrapperRTL.py` | rtl | `sv/rtl/fu/combo/tile_alu_gen_mac.sv` |  |
| `fu/fused_alu_fixedp/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/fused_alu_fixedp/test/AluGenMacRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/fused_alu_fixedp/test/AluGenMacWrapperRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/fused_alu_fixedp/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/others/Im2colEngineRTL.py` | rtl | `sv/rtl/peripheral/cgra_im2col_engine.sv` |  |
| `fu/others/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/others/test/Im2colEngineRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/others/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/quadra/FourIncCmpNotGrantRTL.py` | rtl | `sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv` |  |
| `fu/quadra/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/quadra/test/FourIncCmpNotGrantRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/quadra/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/single/AdderRTL.py` | rtl | `sv/rtl/fu/tile_adder.sv` |  |
| `fu/single/CompRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_comp.sv` |  |
| `fu/single/ConstRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_const.sv` |  |
| `fu/single/DivRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_div.sv` |  |
| `fu/single/ExclusiveDivRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_exclusive_div.sv` |  |
| `fu/single/ExtractPredicateRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_extract_predicate.sv` |  |
| `fu/single/GepRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_gep.sv` |  |
| `fu/single/GrantRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_grant.sv` |  |
| `fu/single/InclusiveDivRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_inclusive_div.sv` | Divisor is intentionally snooped without asserting ready; preserve level-like operand semantics. |
| `fu/single/LogicRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_logic.sv` | SV also implements AND_CONST/OR_CONST, which Python only defines in its ABI. |
| `fu/single/LoopControlRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_loop_control.sv` |  |
| `fu/single/LoopCounterRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_loop_counter.sv` |  |
| `fu/single/MemUnitRTL.py` | rtl | `sv/rtl/fu/tile_memory_fu.sv` |  |
| `fu/single/MulRTL.py` | rtl | `sv/rtl/fu/tile_multiplier.sv` |  |
| `fu/single/NahRTL.py` | rtl | `sv/rtl/fu/tile_nah.sv` |  |
| `fu/single/PhiRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_phi.sv` | Old PHI opcodes retained; explicit native PHI_N/PHI_START_PRED extensions are separate. |
| `fu/single/RetRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_ret.sv` |  |
| `fu/single/SelRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_sel.sv` |  |
| `fu/single/ShifterRTL.py` | rtl | `sv/rtl/fu/scalar/scalar_shifter.sv` |  |
| `fu/single/StreamingMemUnitRTL.py` | rtl | `sv/rtl/fu/streaming/tile_streaming_memory_fu.sv` |  |
| `fu/single/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/single/test/AdderRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/AluRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/CompRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/ConstRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/DivRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/ExclusiveDivRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/ExtractPredicateRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/GepRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/GrantRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/InclusiveDivRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/LoopControlRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/LoopCounterRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/MemUnitRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/MulRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/PhiRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/RetRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/SelRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/StreamingMemUnitRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/single/translate/CompRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/translate/ExclusiveDivRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/translate/InclusiveDivRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/single/translate/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/triple/ThreeMulAdderShifterRTL.py` | rtl | `sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv` |  |
| `fu/triple/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/triple/test/ThreeMulAluShifterRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/triple/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/vector/VectorAdderComboRTL.py` | rtl | `sv/rtl/fu/vector/tile_vector_adder_combo.sv` | Native arithmetic/reset corrections are documented separately from Python compatibility. |
| `fu/vector/VectorAdderRTL.py` | rtl | `sv/rtl/fu/vector/cgra_vector_adder.sv` | Native arithmetic/reset corrections are documented separately from Python compatibility. |
| `fu/vector/VectorAllReduceRTL.py` | rtl | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` | Native arithmetic/reset corrections are documented separately from Python compatibility. |
| `fu/vector/VectorMulComboRTL.py` | rtl | `sv/rtl/fu/vector/tile_vector_mul_combo.sv` | Native arithmetic/reset corrections are documented separately from Python compatibility. |
| `fu/vector/VectorMulRTL.py` | rtl | `sv/rtl/fu/vector/cgra_vector_mul.sv` | Native arithmetic/reset corrections are documented separately from Python compatibility. |
| `fu/vector/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/vector/test/VectorAdderComboRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/test/VectorAdderRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/test/VectorAllReduceRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/test/VectorMulComboRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/test/VectorMulRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `fu/vector/translate/VectorAdderComboRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/translate/VectorMulComboRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `fu/vector/translate/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `lib/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `lib/basic/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `lib/basic/en_rdy/ifcs.py` | framework | `sv/rtl/common/cgra_pe_ports.svh` | RTL signal fields are flattened; Python FL/CL adaptors/string rendering are not SV APIs. |
| `lib/basic/en_rdy/test_sinks.py` | test_support | `sv/tests/current/tb_current_fu.sv`<br>`sv/tests/current/tb_native_kernel.sv` | SV drivers/checkers replace usage, not the original Python helper API. No assertion of original-test execution. |
| `lib/basic/en_rdy/test_srcs.py` | test_support | `sv/tests/current/tb_current_fu.sv`<br>`sv/tests/current/tb_native_kernel.sv` | SV drivers/checkers replace usage, not the original Python helper API. No assertion of original-test execution. |
| `lib/basic/val_rdy/SinkRTL.py` | test_support | `sv/tests/current/tb_current_fu.sv`<br>`sv/tests/current/tb_native_kernel.sv` | SV drivers/checkers replace usage, not the original Python helper API. No assertion of original-test execution. |
| `lib/basic/val_rdy/SourceRTL.py` | test_support | `sv/tests/current/tb_current_fu.sv`<br>`sv/tests/current/tb_native_kernel.sv` | SV drivers/checkers replace usage, not the original Python helper API. No assertion of original-test execution. |
| `lib/basic/val_rdy/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `lib/basic/val_rdy/ifcs.py` | framework | `sv/rtl/common/cgra_pe_ports.svh` | RTL signal fields are flattened; Python FL/CL adaptors/string rendering are not SV APIs. |
| `lib/basic/val_rdy/queues.py` | rtl | `sv/rtl/common/cgra_queue.sv`<br>`sv/rtl/common/cgra_pipe_queue.sv` | Normal/Bypass/clear variants plus standalone PipeQueue; shared datapath/controller classes are inlined. |
| `lib/cmd_type.py` | abi_or_metadata | `sv/tools/abi.json`<br>`sv/rtl/common/cgra_types_pkg.sv` | Encoding/field semantics mapped; Python factory and attribute dictionary API not exported. Opcode/command definitions do not imply dispatch support. |
| `lib/messages.py` | abi_or_metadata | `sv/rtl/common/cgra_profile.svh`<br>`sv/rtl/common/cgra_types_pkg.sv`<br>`sv/tools/cgra_program.py` | Encoding/field semantics mapped; Python factory and attribute dictionary API not exported. Opcode/command definitions do not imply dispatch support. |
| `lib/opt_type.py` | abi_or_metadata | `sv/rtl/common/cgra_opcodes.svh`<br>`sv/tools/abi.json` | Encoding/field semantics mapped; Python factory and attribute dictionary API not exported. Opcode/command definitions do not imply dispatch support. |
| `lib/status_type.py` | abi_or_metadata | `sv/rtl/tile/variants/tile_context_switch.sv` | Encoding/field semantics mapped; Python factory and attribute dictionary API not exported. Opcode/command definitions do not imply dispatch support. |
| `lib/trace_logger.py` | software_not_ported | `sv/tests/current/tb_native_kernel.sv` | Native testbench logs replace selected diagnostics, not the original trace-logger API. |
| `lib/util/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `lib/util/cgra/DataSPM.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `lib/util/cgra/Link.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `lib/util/cgra/Tile.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `lib/util/cgra/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `lib/util/cgra/cgra_helper.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `lib/util/common.py` | abi_or_metadata | `sv/rtl/common/cgra_profile.svh`<br>`sv/tools/cgra_config.py` | Encoding/field semantics mapped; Python factory and attribute dictionary API not exported. Opcode/command definitions do not imply dispatch support. |
| `lib/util/ctrl_helper.py` | bounded_tool | `sv/tools/cgra_program.py` | Explicit program/control JSON packing and barriers; no automatic mapping, scheduler, general YAML/DFG lowering, or exact Python utility API. |
| `lib/util/data_struct_attr.py` | abi_or_metadata | `sv/tools/cgra_config.py`<br>`sv/tools/cgra_program.py` | Encoding/field semantics mapped; Python factory and attribute dictionary API not exported. Opcode/command definitions do not imply dispatch support. |
| `lib/util/dfg_helper.py` | software_not_ported | `sv/tools/cgra_program.py` | General DFG/YAML lowering stays in the original project. Standalone tools accept explicit mapped words, not arbitrary DFGs; original ICMP_ULT mapping defect remains frozen. |
| `lib/util/map_helper.py` | software_not_ported | `sv/tools/cgra_program.py` | General DFG/YAML lowering stays in the original project. Standalone tools accept explicit mapped words, not arbitrary DFGs; original ICMP_ULT mapping defect remains frozen. |
| `local_CI.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `mem/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/const/ConstQueueDynamicRTL.py` | rtl | `sv/rtl/mem/const_queue.sv`<br>`sv/rtl/tile/variants/tile_variant_const_queue.sv` |  |
| `mem/const/ConstQueueRTL.py` | rtl | `sv/rtl/mem/cgra_static_const_queue.sv` |  |
| `mem/const/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/const/test/ConstQueueDynamicRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/const/test/ConstQueueRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/const/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/ctrl/ContextSwitchRTL.py` | rtl | `sv/rtl/tile/variants/tile_context_switch.sv` |  |
| `mem/ctrl/CtrlMemCL.py` | reference_model |  | Functional/cycle-level software model; not an additional RTL implementation or exact migrated software API. |
| `mem/ctrl/CtrlMemDynamicRTL.py` | rtl | `sv/rtl/mem/ctrl_mem.sv`<br>`sv/rtl/tile/variants/tile_variant_ctrl_mem.sv` |  |
| `mem/ctrl/CtrlMemRTL.py` | rtl | `sv/rtl/mem/cgra_static_ctrl_mem.sv` |  |
| `mem/ctrl/RingMultiCtrlMemDynamicRTL.py` | rtl | `sv/rtl/mem/cgra_ring_multi_ctrl_mem.sv` |  |
| `mem/ctrl/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/ctrl/test/ContextSwitchRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/ctrl/test/CtrlMemDynamicRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/ctrl/test/RingCtrlMemDynamicRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/ctrl/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/data/DataMemCL.py` | reference_model |  | Functional/cycle-level software model; not an additional RTL implementation or exact migrated software API. |
| `mem/data/DataMemControllerRTL.py` | rtl | `sv/rtl/mem/cgra_data_bank.sv` |  |
| `mem/data/DataMemRTL.py` | rtl | `sv/rtl/mem/cgra_data_mem.sv` |  |
| `mem/data/DataMemScalableRTL.py` | rtl | `sv/rtl/mem/cgra_data_mem_scalable.sv` | Original extra NoC ports are tied off too; no remote scalable memory support. |
| `mem/data/DataMemWrapperRTL.py` | rtl | `sv/rtl/mem/cgra_data_memory.sv` |  |
| `mem/data/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/data/test/DataMemCL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/data/test/DataMemControllerRTL_dma_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/data/test/DataMemControllerRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/data/test/DataMemRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/data/test/DataMemScalableRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/data/test/DataMemWrapperRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/data/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/dma/DmaEngineRTL.py` | rtl | `sv/rtl/peripheral/cgra_dma_engine.sv` |  |
| `mem/dma/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/dma/test/DmaEngineRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/dma/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/register_cluster/RegisterBankRTL.py` | rtl | `sv/rtl/mem/register_bank.sv` |  |
| `mem/register_cluster/RegisterClusterRTL.py` | rtl | `sv/rtl/mem/register_cluster.sv` |  |
| `mem/register_cluster/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `mem/register_cluster/test/RegisterBankRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/register_cluster/test/RegisterClusterRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `mem/register_cluster/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `multi_cgra/MeshMultiCgraRTL.py` | rtl | `sv/rtl/cgra/cgra_multi.sv` | Native NoC locking/reset/VC normalization differs intentionally; NOC_LEGACY_PYTHON restores supported legacy profiles. |
| `multi_cgra/MeshMultiCgraTemplateRTL.py` | rtl | `sv/rtl/cgra/cgra_multi_template.sv` | Native NoC locking/reset/VC normalization differs intentionally; NOC_LEGACY_PYTHON restores supported legacy profiles. |
| `multi_cgra/RingMultiCgraRTL.py` | rtl | `sv/rtl/cgra/cgra_multi.sv` | Native NoC locking/reset/VC normalization differs intentionally; NOC_LEGACY_PYTHON restores supported legacy profiles. |
| `multi_cgra/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `multi_cgra/arch_parser/ArchParser.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `multi_cgra/arch_parser/MultiCgraParam.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `multi_cgra/arch_parser/ParamCGRA.py` | bounded_tool | `sv/tools/cgra_config.py` | Explicit architecture JSON replaces supported elaboration inputs. Not an exact Python/YAML parser API; sparse deleted tiles and arbitrary custom FU classes are outside scope. |
| `multi_cgra/arch_parser/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `multi_cgra/arch_parser/test/ArchParser_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/arch_parser/test/Overrides_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/arch_parser/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `multi_cgra/arch_parser/test/conftest.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/test/MeshMultiCgraRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/test/MeshMultiCgraTemplateRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/test/MultiCgraRTL_migration_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/test/RingMultiCgraRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/test/RingNetworkRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `multi_cgra/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `noc/ChannelWithClearRTL.py` | rtl | `sv/rtl/common/cgra_channel.sv` |  |
| `noc/CrossbarRTL.py` | rtl | `sv/rtl/noc/cgra_xbar.sv` |  |
| `noc/LinkOrRTL.py` | rtl | `sv/rtl/tile/tile_link_or.sv` |  |
| `noc/OrLinkRTL.py` | rtl | `sv/rtl/noc/cgra_or_link.sv` |  |
| `noc/SelectorRTL.py` | rtl | `sv/rtl/noc/cgra_selector.sv` |  |
| `noc/StaticSwitchUnitRTL.py` | rtl | `sv/rtl/noc/cgra_switch.sv` |  |
| `noc/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `noc/test/ChannelWithClearRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `noc/test/CrossbarRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `noc/test/LinkOrRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `noc/test/OrLinkRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `noc/test/SelectorRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `noc/test/StaticSwitchUnitRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `noc/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `rf/RegFile.py` | rtl | `sv/rtl/common/cgra_reg_file.sv`<br>`sv/rtl/common/cgra_register_file.sv` | Standalone legacy API; unconditionally writes every rising edge even when invalid, stalled or reset. Not used by current PE; storage power-up unspecified. |
| `rf/RegisterRTL.py` | integrated | `sv/rtl/common/cgra_channel.sv` | Queue-chain latency >=1 maps to channel with clear tied low. SV latency=0 is an extension, not a supported Python parameter. |
| `rf/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `rf/test/RegFile_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `rf/test/RegisterRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `rf/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `sys_lib/abc_path_groups.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/area_report.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/class_nldm.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/collect_results.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/equivalence.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/generate.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/local_crossbar_synth.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/mapped_timing.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/structural_cutpoints.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/synthesize.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/validate_nldm.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/verify_cgra.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/verify_crossbar.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `sys_lib/verify_switch.py` | software_not_ported | `sv/scripts/run.ps1`<br>`sv/Makefile` | Original automation/reference/PPA tooling retained, not translated into RTL. Native build/regression replaces selected use cases; no claim of equivalent PPA/AI automation tools. |
| `tile/TileRTL.py` | rtl | `sv/rtl/tile/tile_programmable.sv`<br>`sv/rtl/tile/cgra_pe.sv` | Shared parameterized PE API; ctrl_proceed/token semantics retained. Streaming scalar-retirement defect intentionally fixed. |
| `tile/TileWithContextSwitchRTL.py` | rtl | `sv/rtl/tile/variants/tile_context.sv`<br>`sv/rtl/tile/cgra_pe.sv` | Shared parameterized PE API; ctrl_proceed/token semantics retained. Streaming scalar-retirement defect intentionally fixed. |
| `tile/TileWithStreamingLoadRTL.py` | rtl | `sv/rtl/tile/variants/tile_streaming.sv`<br>`sv/rtl/tile/cgra_pe.sv` | Shared parameterized PE API; ctrl_proceed/token semantics retained. Streaming scalar-retirement defect intentionally fixed. |
| `tile/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `tile/test/TileRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `tile/test/TileWithContextSwitchRTL_test.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |
| `tile/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `tile/translate/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `validation/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `validation/script_generator.py` | bounded_tool | `sv/tools/cgra_program.py` | Explicit program/control JSON packing and barriers; no automatic mapping, scheduler, general YAML/DFG lowering, or exact Python utility API. |
| `validation/test/__init__.py` | package_marker |  | Python package initialization; no RTL API. |
| `validation/test/dummy.py` | original_test |  | Original test retained. Related family evidence is NOT a claim this test ran, passed, translated, or was reproduced exactly. |

## Opcode

下列位置是 dispatch／控制引用，不等于每个 opcode 已完成独立数学或逐周期验证。实际支持还取决于 PE 的 FU catalog。

| Opcode | 编码 | 状态 | SV 位置 |
|---|---:|---|---|
| START | 0 | control_sentinel | `sv/rtl/fu/combo/tile_alu_gen_mac.sv`<br>`sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv`<br>`sv/rtl/fu/combo/tile_prl_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_shifter.sv`<br>`sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv`<br>`sv/rtl/fu/scalar/scalar_comp.sv`<br>`sv/rtl/fu/scalar/scalar_const.sv`<br>`sv/rtl/fu/scalar/scalar_div.sv`<br>`sv/rtl/fu/scalar/scalar_exclusive_div.sv`<br>`sv/rtl/fu/scalar/scalar_extract_predicate.sv`<br>`sv/rtl/fu/scalar/scalar_gep.sv`<br>`sv/rtl/fu/scalar/scalar_grant.sv`<br>`sv/rtl/fu/scalar/scalar_inclusive_div.sv`<br>`sv/rtl/fu/scalar/scalar_logic.sv`<br>`sv/rtl/fu/scalar/scalar_loop_control.sv`<br>`sv/rtl/fu/scalar/scalar_loop_counter.sv`<br>`sv/rtl/fu/scalar/scalar_phi.sv`<br>`sv/rtl/fu/scalar/scalar_ret.sv`<br>`sv/rtl/fu/scalar/scalar_shifter.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/tile_multiplier.sv`<br>`sv/rtl/fu/tile_nah.sv`<br>`sv/rtl/mem/ctrl_mem.sv`<br>`sv/rtl/tile/tile_static_crossbar.sv`<br>`sv/rtl/tile/variants/tile_variant_crossbar.sv`<br>`sv/rtl/tile/variants/tile_variant_ctrl_mem.sv` |
| NAH | 1 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_flexible_fu.sv`<br>`sv/rtl/fu/tile_nah.sv`<br>`sv/rtl/mem/ctrl_mem.sv`<br>`sv/rtl/mem/register_cluster.sv`<br>`sv/rtl/tile/variants/tile_variant_ctrl_mem.sv` |
| ADD | 2 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/combo/tile_alu_gen_mac.sv`<br>`sv/rtl/fu/combo/tile_prl_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/vector/cgra_vector_adder.sv` |
| INC | 3 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/vector/cgra_vector_adder.sv` |
| SUB | 4 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/combo/tile_alu_gen_mac.sv`<br>`sv/rtl/fu/combo/tile_prl_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/vector/cgra_vector_adder.sv` |
| LLS | 5 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_seq_mul_shifter.sv`<br>`sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv`<br>`sv/rtl/fu/scalar/scalar_shifter.sv` |
| LRS | 6 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_seq_mul_shifter.sv`<br>`sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv`<br>`sv/rtl/fu/scalar/scalar_shifter.sv` |
| MUL | 7 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/combo/tile_alu_gen_mac.sv`<br>`sv/rtl/fu/combo/tile_prl_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_shifter.sv`<br>`sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv`<br>`sv/rtl/fu/tile_multiplier.sv`<br>`sv/rtl/fu/vector/cgra_vector_mul.sv` |
| OR | 8 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_logic.sv` |
| XOR | 9 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_logic.sv` |
| AND | 10 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_logic.sv` |
| NOT | 11 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv`<br>`sv/rtl/fu/scalar/scalar_logic.sv` |
| LD | 12 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_memory_fu.sv` |
| STR | 13 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_memory_fu.sv` |
| EQ | 14 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_comp.sv` |
| REM_INCLUSIVE_END | 15 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_inclusive_div.sv` |
| GRT_PRED | 16 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv`<br>`sv/rtl/fu/scalar/scalar_grant.sv` |
| PHI | 17 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_phi.sv` |
| MUL_ADD | 18 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_alu_gen_mac.sv`<br>`sv/rtl/fu/combo/tile_prl_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv` |
| MUL_SUB | 19 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_prl_mul_adder.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv` |
| MUL_LLS | 20 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_seq_mul_shifter.sv` |
| MUL_LRS | 21 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_seq_mul_shifter.sv` |
| MUL_ADD_LLS | 22 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv` |
| MUL_SUB_LLS | 23 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv` |
| MUL_SUB_LRS | 24 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_three_mul_adder_shifter.sv` |
| ADD_CONST | 25 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/vector/cgra_vector_adder.sv` |
| DIV | 26 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_div.sv`<br>`sv/rtl/fu/scalar/scalar_exclusive_div.sv` |
| SEL | 27 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_sel.sv` |
| LD_CONST | 28 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_memory_fu.sv` |
| MUL_CONST | 29 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/tile_multiplier.sv` |
| MUL_CONST_ADD | 30 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_seq_mul_adder.sv` |
| PAS | 31 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/combo/tile_seq_mul_adder.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/vector/cgra_vector_adder.sv` |
| PHI_CONST | 32 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_phi.sv` |
| EQ_CONST | 33 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_comp.sv` |
| GRT_ALWAYS | 34 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_grant.sv` |
| RET | 35 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_ret.sv` |
| SUB_CONST | 36 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_adder.sv`<br>`sv/rtl/fu/vector/cgra_vector_adder.sv` |
| FADD | 37 | implemented_in_selected_fu | `sv/rtl/fu/float/tile_fp_fu.sv` |
| FSUB | 38 | implemented_in_selected_fu | `sv/rtl/fu/float/tile_fp_fu.sv` |
| FADD_CONST | 39 | implemented_in_selected_fu | `sv/rtl/fu/float/tile_fp_fu.sv` |
| FINC | 40 | implemented_in_selected_fu | `sv/rtl/fu/float/tile_fp_fu.sv` |
| FMUL | 41 | implemented_in_selected_fu | `sv/rtl/fu/float/tile_fp_fu.sv` |
| FMUL_CONST | 42 | implemented_in_selected_fu | `sv/rtl/fu/float/tile_fp_fu.sv` |
| BIT_NOT | 43 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_logic.sv` |
| REM | 44 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_exclusive_div.sv` |
| NE | 45 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_comp.sv` |
| NE_CONST | 46 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv`<br>`sv/rtl/fu/scalar/scalar_comp.sv` |
| GRT_ONCE | 47 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_grant.sv` |
| DIV_INCLUSIVE_START | 48 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_inclusive_div.sv` |
| DIV_INCLUSIVE_END | 49 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_inclusive_div.sv` |
| VEC_INC | 50 | defined_only_in_both |  |
| VEC_ADD | 51 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_ADD_CONST | 52 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_SUB | 53 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_SUB_CONST | 54 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_MUL | 55 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_mul.sv`<br>`sv/rtl/fu/vector/tile_vector_mul_combo.sv` |
| VEC_REDUCE_ADD | 56 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| VEC_REDUCE_MUL | 57 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| STR_CONST | 58 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_memory_fu.sv` |
| REM_INCLUSIVE_START | 59 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_inclusive_div.sv` |
| LT | 60 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_alu_gen_mac.sv`<br>`sv/rtl/fu/scalar/scalar_comp.sv` |
| GTE | 61 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_alu_gen_mac.sv` |
| GT | 62 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_alu_gen_mac.sv` |
| LTE | 63 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_alu_gen_mac.sv` |
| RET_VOID | 64 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_ret.sv` |
| DIV_CONST | 65 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_div.sv` |
| VEC_REDUCE_ADD_BASE | 68 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| VEC_REDUCE_MUL_BASE | 69 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| VEC_INC_COMBINED | 70 | defined_only_in_both |  |
| VEC_ADD_COMBINED | 71 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_ADD_CONST_COMBINED | 72 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_SUB_COMBINED | 73 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_SUB_CONST_COMBINED | 74 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_adder.sv`<br>`sv/rtl/fu/vector/tile_vector_adder_combo.sv` |
| VEC_MUL_COMBINED | 75 | implemented_in_selected_fu | `sv/rtl/fu/vector/cgra_vector_mul.sv`<br>`sv/rtl/fu/vector/tile_vector_mul_combo.sv` |
| VEC_REDUCE_ADD_GLOBAL | 76 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| VEC_REDUCE_MUL_GLOBAL | 77 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| VEC_REDUCE_ADD_BASE_GLOBAL | 78 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| VEC_REDUCE_MUL_BASE_GLOBAL | 79 | implemented_in_selected_fu | `sv/rtl/fu/vector/tile_vector_all_reduce.sv` |
| CONST | 80 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_const.sv` |
| ADD_CONST_LD | 81 | implemented_in_selected_fu | `sv/rtl/common/cgra_types_pkg.sv`<br>`sv/rtl/fu/tile_memory_fu.sv` |
| INC_NE_CONST_NOT_GRT | 82 | implemented_in_selected_fu | `sv/rtl/fu/combo/tile_four_inc_cmp_not_grant.sv` |
| LOOP_CONTROL | 83 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_loop_control.sv`<br>`sv/rtl/fu/scalar/scalar_loop_control_native.sv` |
| PHI_START | 84 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_phi.sv` |
| LOOP_COUNT | 85 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_loop_counter.sv` |
| LOOP_DELIVERY | 86 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_loop_counter.sv` |
| EXTRACT_PREDICATE | 87 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_extract_predicate.sv` |
| GRT_ONCE_CONST | 88 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_grant.sv` |
| STREAM_LD | 89 | implemented_in_selected_fu | `sv/rtl/fu/streaming/tile_streaming_memory_fu.sv`<br>`sv/rtl/tile/variants/tile_variant_core.sv` |
| GTE_CONST | 90 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_comp.sv` |
| GEP | 92 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_gep.sv` |
| GEP_CONST | 93 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_gep.sv` |
| GEP_2D | 94 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_gep.sv` |
| GEP_2D_CONST | 95 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_gep.sv` |
| LLS_CONST | 96 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_shifter.sv` |
| GT_CONST | 97 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_comp.sv` |
| LT_CONST | 98 | implemented_in_selected_fu | `sv/rtl/fu/scalar/scalar_comp.sv` |
| REM_CONST | 99 | defined_only_in_both |  |
| AND_CONST | 100 | native_implementation_at_python_reserved_encoding | `sv/rtl/fu/scalar/scalar_logic.sv` |
| OR_CONST | 101 | native_implementation_at_python_reserved_encoding | `sv/rtl/fu/scalar/scalar_logic.sv` |
| ULT | 102 | native_encoding_extension | `sv/rtl/fu/scalar/scalar_comp.sv` |
| ULT_CONST | 103 | native_encoding_extension | `sv/rtl/fu/scalar/scalar_comp.sv` |
| PHI_N | 104 | native_encoding_extension | `sv/rtl/fu/scalar/scalar_phi.sv` |
| PHI_START_PRED | 105 | native_encoding_extension | `sv/rtl/fu/scalar/scalar_phi.sv` |

## 命令与可达性

能打包不代表任意顶层可处理。组件侧端口支持与 CPU → Controller → Tile 路由分开判断。

| Command | 编码 | 范围 |
|---|---:|---|
| LAUNCH | 0 | Base/Context/Streaming host-to-tile configuration |
| PAUSE | 1 | Context host ingress only; Base/Streaming reject at tile ingress |
| TERMINATE | 2 | Context host ingress only; Base/Streaming reject at tile ingress |
| CONFIG | 3 | Base/Context/Streaming host-to-tile configuration |
| CONFIG_PROLOGUE_FU | 4 | Base/Context/Streaming host-to-tile configuration |
| CONFIG_PROLOGUE_FU_CROSSBAR | 5 | Base/Context/Streaming host-to-tile configuration |
| CONFIG_PROLOGUE_ROUTING_CROSSBAR | 6 | Base/Context/Streaming host-to-tile configuration |
| CONFIG_TOTAL_CTRL_COUNT | 7 | Base/Context/Streaming host-to-tile configuration |
| CONFIG_COUNT_PER_ITER | 8 | Base/Context/Streaming host-to-tile configuration |
| CONFIG_CTRL_LOWER_BOUND | 9 | Context host ingress only; Base/Streaming reject at tile ingress |
| LOAD_REQUEST | 10 | Controller memory request/response or completion traffic; direction matters |
| LOAD_RESPONSE | 11 | Controller memory request/response or completion traffic; direction matters |
| STORE_REQUEST | 12 | Controller memory request/response or completion traffic; direction matters |
| CONST | 13 | Base/Context/Streaming host-to-tile configuration |
| COMPLETE | 14 | Controller memory request/response or completion traffic; direction matters |
| RESUME | 15 | Context host ingress only; Base/Streaming reject at tile ingress |
| RECORD_PHI_ADDR | 16 | Context host ingress only; Base/Streaming reject at tile ingress |
| GLOBAL_REDUCE_COUNT | 17 | Global reduction request/count/response; configured participant count required |
| GLOBAL_REDUCE_ADD | 18 | Global reduction request/count/response; configured participant count required |
| GLOBAL_REDUCE_MUL | 19 | Global reduction request/count/response; configured participant count required |
| GLOBAL_REDUCE_ADD_RESPONSE | 20 | Global reduction request/count/response; configured participant count required |
| GLOBAL_REDUCE_MUL_RESPONSE | 21 | Global reduction request/count/response; configured participant count required |
| PRESERVE | 22 | Context host ingress only; Base/Streaming reject at tile ingress |
| CONFIG_STREAMING_LD_START_ADDR | 23 | Streaming memory FU sideband; accepted by Context ingress but has no streaming FU there |
| CONFIG_STREAMING_LD_STRIDE | 24 | Streaming memory FU sideband; accepted by Context ingress but has no streaming FU there |
| CONFIG_STREAMING_LD_END_ADDR | 25 | Streaming memory FU sideband; accepted by Context ingress but has no streaming FU there |
| UPDATE_COUNTER_SHADOW_VALUE | 26 | LoopCounter/ctrl-memory sideband only; no LoopController system routing |
| RESET_LEAF_COUNTER | 27 | LoopCounter/ctrl-memory sideband only; no LoopController system routing |
| CONFIG_LOOP_LOWER | 28 | Base host ingress + LoopCounter sideband; Context/Streaming ingress omits these commands |
| CONFIG_LOOP_UPPER | 29 | Base host ingress + LoopCounter sideband; Context/Streaming ingress omits these commands |
| CONFIG_LOOP_STEP | 30 | Base host ingress + LoopCounter sideband; Context/Streaming ingress omits these commands |
| LEAF_COUNTER_COMPLETE | 31 | LoopCounter/ctrl-memory sideband only; no LoopController system routing |
| LC_CONFIG_LOWER | 32 | Standalone LoopController API; absent from integrated controller routing |
| LC_CONFIG_UPPER | 33 | Standalone LoopController API; absent from integrated controller routing |
| LC_CONFIG_STEP | 34 | Standalone LoopController API; absent from integrated controller routing |
| LC_CONFIG_CHILD_COUNT | 35 | Standalone LoopController API; absent from integrated controller routing |
| LC_CONFIG_TARGET | 36 | Standalone LoopController API; absent from integrated controller routing |
| LC_CONFIG_PARENT | 37 | Standalone LoopController API; absent from integrated controller routing |
| LC_LAUNCH | 38 | Standalone LoopController API; absent from integrated controller routing |
| LC_SYNC_VALUE | 39 | Standalone LoopController API; absent from integrated controller routing |
| LC_CHILD_COMPLETE | 40 | Standalone LoopController API; absent from integrated controller routing |
| LC_CHILD_RESET | 41 | Standalone LoopController API; absent from integrated controller routing |
| LC_ALL_COMPLETE | 42 | Standalone LoopController API; absent from integrated controller routing |
| CONFIG_GEP_STRIDE | 43 | GEP stride configuration routed in all three tile variants; Python controller omission corrected |
| DMA_CONFIG_DRAM_ADDR_LO | 44 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_CONFIG_DRAM_ADDR_HI | 45 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_CONFIG_SPM_ADDR | 46 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_CONFIG_BYTES | 47 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_CONFIG_TAG | 48 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_MVIN | 49 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_MVOUT | 50 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| DMA_DONE | 51 | Integrated DMA/controller only; 32-bit SPM and whole-word lengths |
| IM2COL_LAUNCH | 52 | Integrated im2col/controller only; native launch fence and restart contract |
| IM2COL_H | 53 | Integrated im2col/controller only; native launch fence and restart contract |
| IM2COL_W | 54 | Integrated im2col/controller only; native launch fence and restart contract |
| IM2COL_KH | 55 | Integrated im2col/controller only; native launch fence and restart contract |
| IM2COL_KW | 56 | Integrated im2col/controller only; native launch fence and restart contract |
| IM2COL_LOG2_STRIDE | 57 | Integrated im2col/controller only; native launch fence and restart contract |
| IM2COL_DST_SRAM_BASE | 58 | Integrated im2col/controller only; native launch fence and restart contract |
