MODULE=simd32_top

TOP_DIR := ../..
SRC_DIR := $(TOP_DIR)/src
VERIL_DIR := $(TOP_DIR)/veril
TB_DIR := $(VERIL_DIR)/donut

# IGNORED_FILES := $(SRC_DIR)/simd32_top.sv
IGNORED_FILES := NONE

# SRC=$(wildcard $(SRC_DIR)/*.sv)
ALL_SRC_FILES = $(shell find $(SRC_DIR) -name "*.svh")
ALL_SRC_FILES += $(shell find $(SRC_DIR) -name "*.sv")
ALL_SRC_FILES += $(VERIL_DIR)/simulation_verilog/dual_port_RAM.sv

SRC = $(filter-out $(IGNORED_FILES) ,$(ALL_SRC_FILES))


TB = $(TB_DIR)/main.cpp


.PHONY:waves
waves: waveform.vcd
	@echo
	@echo "### WAVES ###"
	gtkwave waveform.vcd -a gtkwave_setup.gtkw

waveform.vcd: ./obj_dir/V$(MODULE)
	@echo
	@echo "### SIMULATING ###"
	./obj_dir/V$(MODULE) +verilator+rand+reset+2 

./obj_dir/V$(MODULE): .stamp.verilate
	@echo
	@echo "### BUILDING SIM ###"
	make -C obj_dir -f V$(MODULE).mk V$(MODULE)

.stamp.verilate: $(SRC) $(TB)
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace --x-assign unique --x-initial unique -cc $(SRC) --exe $(TB) -Wno-UNUSEDPARAM --top-module $(MODULE) --trace-structs -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN
	@touch .stamp.verilate

.PHONY:clean
clean:
	rm -rf obj_dir
	rm .stamp.verilate

.PHONY:lint
lint: $(SRC)
	verilator --lint-only $(SRC) -Wno-UNUSEDPARAM --top-module $(MODULE)

.PHONY:rerun
rerun:
	./obj_dir/V$(MODULE) +verilator+rand+reset+2 