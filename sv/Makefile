# Run from sv/: make probe, make sim, make negative, make synth.
# No project Python or PyMTL is used. Verilator may use its own Python helpers.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all

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
RTL_FILES := $(shell cat filelists/rtl.f)
SIM_FILES := $(RTL_FILES) reference/VectorCGRA2x2Reference.v tb/scalar_workload_pkg.sv tb/tb_cgra_2x2_scalar.sv
PROBE_FILES := scripts/probes/tool_probe.sv scripts/probes/tb_tool_probe.sv

.PHONY: all probe types sim negative timeout-negative synth synth-generic synth-mapped versions
all: types sim negative timeout-negative synth

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

$(BUILD_DIR)/sim/cgra_sim$(EXEEXT): $(SIM_FILES) filelists/rtl.f filelists/sim.f Makefile
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

$(BUILD_DIR)/types/types_test$(EXEEXT): rtl/common/cgra_types_pkg.sv tb/tb_cgra_types.sv Makefile
	@mkdir -p $(BUILD_DIR)/types
	@$(VERILATOR) --cc --main --exe --timing --compiler $(COMPILER) --top-module tb_cgra_types --prefix Vtypes --Mdir $(BUILD_DIR)/types -o types_test -CFLAGS -std=c++20 $(VERILATOR_WARN_FLAGS) rtl/common/cgra_types_pkg.sv tb/tb_cgra_types.sv > $(BUILD_DIR)/types/verilate.log 2>&1 || { tail -n 40 $(BUILD_DIR)/types/verilate.log; exit 1; }
	@$(MAKE) -C $(BUILD_DIR)/types -f Vtypes.mk -j $(JOBS) "CXX=$(CXX)" "LINK=env -u LINK $(CXX)" $(MODEL_MAKE_FLAGS) > $(BUILD_DIR)/types/compile.log 2>&1 || { tail -n 40 $(BUILD_DIR)/types/compile.log; exit 1; }

types: $(BUILD_DIR)/types/types_test$(EXEEXT)
	@./$(BUILD_DIR)/types/types_test$(EXEEXT) > $(BUILD_DIR)/types/run.log 2>&1 || { cat $(BUILD_DIR)/types/run.log; exit 1; }
	@grep -q 'CGRA_TYPES_PASS' $(BUILD_DIR)/types/run.log
	@cat $(BUILD_DIR)/types/run.log

$(BUILD_DIR)/synth/design.v: $(RTL_FILES) filelists/rtl.f
	@mkdir -p $(BUILD_DIR)/synth
	@$(SV2V) $(RTL_FILES) --top=cgra_2x2 --write=$@

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
