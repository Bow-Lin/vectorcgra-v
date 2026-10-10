# Run from sv/: make probe, make sim, make negative, make synth.
# No project Python or PyMTL is used. Verilator may use its own Python helpers.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := current

VERILATOR ?= verilator
SV2V ?= sv2v
YOSYS ?= yosys
COMPILER ?= gcc
JOBS ?= 2
BUILD_DIR ?= build
EXEEXT ?=
LIBERTY ?=
MODEL_MAKE_FLAGS ?=
VERILATOR_WARN_FLAGS ?= -Wno-TIMESCALEMOD
CGRA_WARN_FLAGS ?= -Wno-fatal
PHASE2_GEOMETRIES := 2x2 3x2 4x4 2x2-w64-c16-r8
PHASE2_REF_2x2 := Phase2Reference2x2
PHASE2_REF_3x2 := Phase2Reference3x2
PHASE2_REF_4x4 := Phase2Reference4x4
PHASE2_REF_2x2-w64-c16-r8 := Phase2Reference2x2W64C16R8
PHASE2_ARGS_2x2 := -GCOLS=2 -GROWS=2
PHASE2_ARGS_3x2 := -GCOLS=3 -GROWS=2
PHASE2_ARGS_4x4 := -GCOLS=4 -GROWS=4
PHASE2_ARGS_2x2-w64-c16-r8 := -GCOLS=2 -GROWS=2 -GDATA_W=64 -GCTRL_DEPTH=16 -GREG_DEPTH=8
RTL_FILES := $(filter-out +incdir+%,$(shell cat filelists/rtl.f))
RTL_HEADERS := $(wildcard rtl/common/*.svh)
SIM_FILES := $(RTL_FILES) reference/VectorCGRA2x2Reference.v tests/scalar_workload_pkg.sv tests/tb_cgra_2x2_scalar.sv
PROBE_FILES := scripts/probes/tool_probe.sv scripts/probes/tb_tool_probe.sv

.PHONY: all probe types sim negative timeout-negative synth synth-generic synth-mapped versions
all: current

.PHONY: current current-synth current-post-synth current-kernels current-prefixes native-kernels native-math native-multi native-template current-migration current-loop-controller current-loop-controller-synth baseline
current:
	bash tests/current/run.sh
current-synth:
	bash scripts/synth_current.sh
current-post-synth:
	bash tests/current/run_synth_pe.sh base context streaming base64 context8
	bash tests/current/run_synth_phi.sh
current-kernels:
	bash tests/current/run_kernels.sh axpy fir4x4 histogram relu4x4 sad
current-prefixes:
	bash tests/current/run_prefixes.sh gemm gemv
native-kernels:
	bash tests/current/run_native_kernels.sh gemm gemv spmv spmv_coo
native-math:
	bash tests/current/run_native_math.sh
	bash tests/current/run_fp_compat.sh
native-multi:
	bash tests/current/run_native_multi.sh
native-template:
	bash tests/current/run_native_template.sh
current-migration:
	bash tests/current/run_migration.sh global_add
	bash tests/current/run_migration.sh dynamic_fir
current-loop-controller:
	bash tests/current/run_loop_controller.sh
current-loop-controller-synth:
	bash tests/current/run_loop_controller.sh synth
.PHONY: current-static-memory current-static-memory-synth
current-static-memory:
	bash tests/current/run_static_memory.sh
current-static-memory-synth:
	bash tests/current/run_static_memory.sh synth
.PHONY: current-ring-ctrl-memory current-ring-ctrl-memory-synth
current-ring-ctrl-memory:
	bash tests/current/run_ring_ctrl_memory.sh
current-ring-ctrl-memory-synth:
	bash tests/current/run_ring_ctrl_memory.sh synth
.PHONY: current-data-memory current-data-memory-synth
current-data-memory:
	bash tests/current/run_data_memory.sh
current-data-memory-synth:
	bash tests/current/run_data_memory.sh synth
.PHONY: current-scalable-memory current-scalable-memory-synth
current-scalable-memory:
	bash tests/current/run_data_memory.sh rtl scalable
current-scalable-memory-synth:
	bash tests/current/run_data_memory.sh synth scalable
.PHONY: current-or-link current-or-link-synth
current-or-link:
	bash tests/current/run_or_link.sh
current-or-link-synth:
	bash tests/current/run_or_link.sh synth
baseline:
	bash scripts/run_baseline.sh all

.PHONY: phase2 phase2-negative $(addprefix phase2-,$(PHASE2_GEOMETRIES))
phase2: $(addprefix phase2-,$(PHASE2_GEOMETRIES)) phase2-negative

# Phase 3 runners consume maintained HDL and frozen text assets only.
# Historical contracts: run via scripts/run_baseline.sh phase3 after migration.
.PHONY: phase3 phase3-system phase3-scalar phase3-vector-combo phase3-float phase3-tiles
phase3: phase3-scalar phase3-vector-combo phase3-float phase3-tiles phase3-system
phase3-scalar:
	bash tests/phase3/scalar/run.sh w32
	bash tests/phase3/scalar/run.sh w64
phase3-vector-combo:
	bash tests/phase3/vector_combo/run.sh
	bash tests/phase3/vector_combo/run_multp.sh
	bash tests/phase3/vector_combo/run_negative.sh
phase3-float:
	bash tests/phase3/float/run.sh
phase3-tiles:
	bash tests/phase3/tile_variants/run_components.sh
	bash tests/phase3/tile_variants/run_tiles.sh
phase3-system:
	bash tests/phase3/system/run_base.sh
	bash tests/phase3/system/run_logic.sh
	bash tests/phase3/system/run_float.sh
	bash tests/phase3/system/run_vector.sh
	bash tests/phase3/system/run_negative.sh
	bash tests/phase3/tile_variants/run_cgra.sh

# Stage 4 compiles maintained SV and frozen HDL/text assets directly.
.PHONY: regression phase4 phase4-noc phase4-system phase4-template phase4-migration phase4-peripheral phase4-memory
regression: current current-synth current-post-synth current-kernels current-prefixes native-kernels native-math native-multi native-template current-migration current-loop-controller current-loop-controller-synth current-static-memory current-static-memory-synth current-ring-ctrl-memory current-ring-ctrl-memory-synth current-data-memory current-data-memory-synth current-scalable-memory current-scalable-memory-synth current-or-link current-or-link-synth baseline
phase4: phase4-noc phase4-system phase4-template phase4-migration phase4-peripheral phase4-memory
phase4-noc:
	bash tests/phase4/noc/run.sh
	bash tests/phase4/noc/run_negative.sh
phase4-system:
	@for profile in mesh4-tiles2 ring4-tiles2 mesh4-tiles2-registered mesh4-tiles4; do JOBS=$(JOBS) bash tests/phase4/system/run.sh $$profile; bash tests/phase4/system/run_negative.sh $$profile; done
phase4-template:
	bash tests/phase4/template/run.sh
phase4-migration:
	bash tests/phase4/migration/run.sh global_add
	bash tests/phase4/migration/run.sh dynamic_fir
phase4-memory:
	bash tests/phase4/memory/run.sh
phase4-peripheral:
	bash tests/phase4/peripheral/run_components.sh
	bash tests/phase4/peripheral/run_systems.sh
# Each geometry has its own frozen ac96 module namespace and executable.
define PHASE2_RULE
$(BUILD_DIR)/phase2/$(1)/cgra_sim$(EXEEXT): $(RTL_FILES) $(RTL_HEADERS) tests/phase2_tb_cgra_scalar.sv reference/phase2/$(1)/$(PHASE2_REF_$(1)).v filelists/rtl.f Makefile
	@mkdir -p $(BUILD_DIR)/phase2/$(1)
	@echo "Compiling native scalar $(1) and its frozen ac96 reference"
	@$(VERILATOR) --cc --main --exe --timing --compiler $(COMPILER) --top-module phase2_tb_cgra_scalar --prefix Vphase2 --Mdir $(BUILD_DIR)/phase2/$(1) -o cgra_sim -CFLAGS -std=c++20 $(VERILATOR_WARN_FLAGS) $(CGRA_WARN_FLAGS) $(PHASE2_ARGS_$(1)) +define+PHASE2_REFERENCE_MODULE=$(PHASE2_REF_$(1)) -f filelists/rtl.f reference/phase2/$(1)/$(PHASE2_REF_$(1)).v tests/phase2_tb_cgra_scalar.sv > $(BUILD_DIR)/phase2/$(1)/verilate.log 2>&1 || { tail -n 60 $(BUILD_DIR)/phase2/$(1)/verilate.log; exit 1; }
	@$(MAKE) -C $(BUILD_DIR)/phase2/$(1) -f Vphase2.mk -j $(JOBS) "CXX=$(CXX)" "LINK=env -u LINK $(CXX)" $(MODEL_MAKE_FLAGS) > $(BUILD_DIR)/phase2/$(1)/compile.log 2>&1 || { tail -n 40 $(BUILD_DIR)/phase2/$(1)/compile.log; exit 1; }

phase2-$(1): $(BUILD_DIR)/phase2/$(1)/cgra_sim$(EXEEXT)
	@./$(BUILD_DIR)/phase2/$(1)/cgra_sim$(EXEEXT) +VECTORS=$(CURDIR)/vectors/phase2/$(1) > $(BUILD_DIR)/phase2/$(1)/run.log 2>&1 || { tail -n 60 $(BUILD_DIR)/phase2/$(1)/run.log; exit 1; }
	@grep -q 'PHASE2_CGRA_PASS' $(BUILD_DIR)/phase2/$(1)/run.log
	@cat $(BUILD_DIR)/phase2/$(1)/run.log
endef
$(foreach geometry,$(PHASE2_GEOMETRIES),$(eval $(call PHASE2_RULE,$(geometry))))

phase2-negative: $(BUILD_DIR)/phase2/3x2/cgra_sim$(EXEEXT)
	@set +e; ./$(BUILD_DIR)/phase2/3x2/cgra_sim$(EXEEXT) +VECTORS=$(CURDIR)/vectors/phase2/3x2 +EXPECT_FAILURE > $(BUILD_DIR)/phase2/3x2/negative.log 2>&1; result=$$?; set -e; test $$result -ne 0; grep -q 'intentional negative control' $(BUILD_DIR)/phase2/3x2/negative.log
	@set +e; ./$(BUILD_DIR)/phase2/3x2/cgra_sim$(EXEEXT) +VECTORS=$(CURDIR)/vectors/phase2/3x2 +STALL_FOREVER +MAX_CYCLES=300 > $(BUILD_DIR)/phase2/3x2/timeout-negative.log 2>&1; result=$$?; set -e; test $$result -ne 0; grep -q 'TIMEOUT scenario=' $(BUILD_DIR)/phase2/3x2/timeout-negative.log
	@echo 'PHASE2_NEGATIVE_PASS: incorrect result and permanent backpressure failed as expected'

versions:
	@$(VERILATOR) --version
	@$(CXX) --version | head -n 1
	@$(SV2V) --version
	@$(YOSYS) -V

$(BUILD_DIR)/probe/tool_probe$(EXEEXT): $(PROBE_FILES) Makefile
	@mkdir -p $(BUILD_DIR)/probe
	@echo "Building SystemVerilog tool probe"
	@$(VERILATOR) --cc --main --exe --timing --compiler $(COMPILER) --top-module tb_tool_probe --prefix Vtool_probe --Mdir $(BUILD_DIR)/probe -o tool_probe -CFLAGS -std=c++20 $(VERILATOR_WARN_FLAGS) $(PROBE_FILES) > $(BUILD_DIR)/probe/verilate.log 2>&1 || { tail -n 40 $(BUILD_DIR)/probe/verilate.log; exit 1; }
	@$(MAKE) -C $(BUILD_DIR)/probe -f Vtool_probe.mk -j $(JOBS) "CXX=$(CXX)" "LINK=env -u LINK $(CXX)" $(MODEL_MAKE_FLAGS) > $(BUILD_DIR)/probe/compile.log 2>&1 || { tail -n 40 $(BUILD_DIR)/probe/compile.log; exit 1; }

probe: $(BUILD_DIR)/probe/tool_probe$(EXEEXT)
	@./$(BUILD_DIR)/probe/tool_probe$(EXEEXT) > $(BUILD_DIR)/probe/run.log 2>&1
	@grep -q '^TOOL_PROBE_PASS' $(BUILD_DIR)/probe/run.log
	@set +e; ./$(BUILD_DIR)/probe/tool_probe$(EXEEXT) +EXPECT_FAILURE > $(BUILD_DIR)/probe/negative.log 2>&1; result=$$?; set -e; test $$result -ne 0; grep -q 'intentional negative control' $(BUILD_DIR)/probe/negative.log
	@$(SV2V) scripts/probes/tool_probe.sv --write=$(BUILD_DIR)/probe/design.v
	@$(YOSYS) -Q -T -p 'read_verilog $(BUILD_DIR)/probe/design.v; hierarchy -check -top tool_probe; synth -top tool_probe; check -assert; stat' > $(BUILD_DIR)/probe/synth.log 2>&1 || { tail -n 40 $(BUILD_DIR)/probe/synth.log; exit 1; }
	@echo 'TOOL_PROBE_PASS: simulation, negative exit, sv2v, synthesis/check'

$(BUILD_DIR)/sim/cgra_sim$(EXEEXT): $(SIM_FILES) $(RTL_HEADERS) filelists/rtl.f filelists/sim.f Makefile
	@mkdir -p $(BUILD_DIR)/sim
	@echo "Compiling native 2x2 and frozen reference"
	@$(VERILATOR) --cc --main --exe --timing --compiler $(COMPILER) --top-module tb_cgra_2x2_scalar --prefix Vcgra2x2 --Mdir $(BUILD_DIR)/sim -o cgra_sim -CFLAGS -std=c++20 $(VERILATOR_WARN_FLAGS) $(CGRA_WARN_FLAGS) -f filelists/sim.f > $(BUILD_DIR)/sim/verilate.log 2>&1 || { tail -n 60 $(BUILD_DIR)/sim/verilate.log; exit 1; }
	@$(MAKE) -C $(BUILD_DIR)/sim -f Vcgra2x2.mk -j $(JOBS) "CXX=$(CXX)" "LINK=env -u LINK $(CXX)" $(MODEL_MAKE_FLAGS) > $(BUILD_DIR)/sim/compile.log 2>&1 || { tail -n 40 $(BUILD_DIR)/sim/compile.log; exit 1; }

sim: $(BUILD_DIR)/sim/cgra_sim$(EXEEXT)
	@./$(BUILD_DIR)/sim/cgra_sim$(EXEEXT) +VECTORS=$(CURDIR)/vectors > $(BUILD_DIR)/sim/run.log 2>&1 || { tail -n 60 $(BUILD_DIR)/sim/run.log; exit 1; }
	@grep -q 'CGRA_2X2_PASS' $(BUILD_DIR)/sim/run.log || { cat $(BUILD_DIR)/sim/run.log; exit 1; }
	@cat $(BUILD_DIR)/sim/run.log

negative: $(BUILD_DIR)/sim/cgra_sim$(EXEEXT)
	@set +e; ./$(BUILD_DIR)/sim/cgra_sim$(EXEEXT) +VECTORS=$(CURDIR)/vectors +EXPECT_FAILURE > $(BUILD_DIR)/sim/negative.log 2>&1; result=$$?; set -e; test $$result -ne 0; grep -q 'intentional negative control' $(BUILD_DIR)/sim/negative.log
	@echo 'NEGATIVE_CONTROL_PASS: intentionally incorrect expectation failed'

timeout-negative: $(BUILD_DIR)/sim/cgra_sim$(EXEEXT)
	@set +e; ./$(BUILD_DIR)/sim/cgra_sim$(EXEEXT) +VECTORS=$(CURDIR)/vectors +STALL_FOREVER +MAX_CYCLES=200 > $(BUILD_DIR)/sim/timeout-negative.log 2>&1; result=$$?; set -e; test $$result -ne 0; grep -q 'TIMEOUT scenario=' $(BUILD_DIR)/sim/timeout-negative.log
	@echo 'TIMEOUT_CONTROL_PASS: permanent backpressure failed with timeout'

$(BUILD_DIR)/types/types_test$(EXEEXT): rtl/common/cgra_types_pkg.sv tests/tb_cgra_types.sv $(RTL_HEADERS) Makefile
	@mkdir -p $(BUILD_DIR)/types
	@$(VERILATOR) --cc --main --exe --timing --compiler $(COMPILER) --top-module tb_cgra_types --prefix Vtypes --Mdir $(BUILD_DIR)/types -o types_test -CFLAGS -std=c++20 $(VERILATOR_WARN_FLAGS) -Irtl/common rtl/common/cgra_types_pkg.sv tests/tb_cgra_types.sv > $(BUILD_DIR)/types/verilate.log 2>&1 || { tail -n 40 $(BUILD_DIR)/types/verilate.log; exit 1; }
	@$(MAKE) -C $(BUILD_DIR)/types -f Vtypes.mk -j $(JOBS) "CXX=$(CXX)" "LINK=env -u LINK $(CXX)" $(MODEL_MAKE_FLAGS) > $(BUILD_DIR)/types/compile.log 2>&1 || { tail -n 40 $(BUILD_DIR)/types/compile.log; exit 1; }

types: $(BUILD_DIR)/types/types_test$(EXEEXT)
	@./$(BUILD_DIR)/types/types_test$(EXEEXT) > $(BUILD_DIR)/types/run.log 2>&1 || { cat $(BUILD_DIR)/types/run.log; exit 1; }
	@grep -q 'CGRA_TYPES_PASS' $(BUILD_DIR)/types/run.log
	@cat $(BUILD_DIR)/types/run.log

$(BUILD_DIR)/synth/design.v: $(RTL_FILES) $(RTL_HEADERS) filelists/rtl.f
	@mkdir -p $(BUILD_DIR)/synth
	@$(SV2V) -Irtl/common $(RTL_FILES) --top=cgra_2x2 --write=$@

synth: synth-generic $(if $(strip $(LIBERTY)),synth-mapped,)

$(BUILD_DIR)/synth/generic.json: $(BUILD_DIR)/synth/design.v
	@echo "Synthesizing native 2x2 (generic cells)"
	@$(YOSYS) -Q -T -p 'read_verilog $(BUILD_DIR)/synth/design.v; hierarchy -check -top cgra_2x2; synth -top cgra_2x2 -noabc; check -assert; tee -o $(BUILD_DIR)/synth/generic-stat.json stat -json; write_json $(BUILD_DIR)/synth/generic.json' > $(BUILD_DIR)/synth/generic.log 2>&1 || { tail -n 60 $(BUILD_DIR)/synth/generic.log; exit 1; }
	@echo 'SYNTH_GENERIC_PASS: hierarchy and check -assert passed'

synth-generic: $(BUILD_DIR)/synth/generic.json

synth-mapped: $(BUILD_DIR)/synth/generic.json
	@test -n '$(LIBERTY)' || { echo 'Set LIBERTY to a standard-cell Liberty file'; exit 1; }
	@printf 'set_driving_cell BUF_X1\nset_load 5.0\n' > $(BUILD_DIR)/synth/abc.constr
	@echo "Mapping native 2x2 to $(LIBERTY)"
	@$(YOSYS) -Q -T -p 'read_json $(BUILD_DIR)/synth/generic.json; hierarchy -check -top cgra_2x2; dfflibmap -liberty "$(LIBERTY)"; abc -liberty "$(LIBERTY)" -constr $(BUILD_DIR)/synth/abc.constr; clean; tee -o $(BUILD_DIR)/synth/mapped-stat.json stat -json -liberty "$(LIBERTY)"; write_json $(BUILD_DIR)/synth/mapped.json; read_liberty -lib -ignore_miss_func "$(LIBERTY)"; check -mapped -assert' > $(BUILD_DIR)/synth/mapped.log 2>&1 || { tail -n 60 $(BUILD_DIR)/synth/mapped.log; exit 1; }
	@echo 'SYNTH_MAPPED_PASS: mapped stat and check -mapped -assert passed'
