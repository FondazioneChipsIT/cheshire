################################
#    ZOIX fault simulation     #
################################

BENDER ?= bender

VCS         :=  vcs
VLOGAN_ZOIX :=  vlogan
VERDI  		:=  verdi
FCM    		:=  vc_fcm

VERDI_PATH  := $(shell dirname $(shell dirname $(shell which $(VERDI))))

ROOT_DIR  := target/zoix
BUILD_DIR := target/zoix/build
NUM_FAULT_SIM := 100000
FAULT_START_CYCLE := 453500
FAULT_END_CYCLE   := 1280000

FAULTSIM_TB := tb_cheshire_soc

ZOIX_BINARY=../../sw/tests/helloworld.spm.elf
ZOIX_BOOTMODE=0
ZOIX_PRELMODE=1
#ZOIX_SELCFG=7

BENDER_ARGS += $(CHS_BENDER_RTL_FLAGS)
BENDER_ARGS += -t vcs -t sim -t test -D SYNTHESIS -D SIMULATION -D SYNTHESIS -D SIMULATION -D VCS -t ZOIX -D VC_Z01X
#BENDER_ARGS += -DREL_CORE
VCS_SCRIPT_ARGS := -assert svaext +v2k -kdb -override_timescale=1ns/10ps -debug_access+all

ZOIX_SCRIPT_ARGS := -work work -nc -xlrm nettype_array -debug_access+class -debug_access+pp -debug_region=lib+cell -debug_access+fwn -debug_access+cbkd +incdir+$(CURDIR) +incdir+$(CURDIR)/target/zoix +incdir+$(CURDIR)/target/sim/src +incdir+$(CURDIR)/hw

$(BUILD_DIR)/compile_rtl.sh: $(CHS_ROOT)/Bender.lock $(CHS_ROOT)/Bender.yml
	mkdir -p $(BUILD_DIR)
	$(BENDER) script vcs $(BENDER_ARGS) --vlog-arg="$(VCS_SCRIPT_ARGS) $(ZOIX_SCRIPT_ARGS)" --vlogan-bin="$(VLOGAN_ZOIX)" > $@
	chmod +x $@

.PHONY: build-zoix
build-zoix: $(BUILD_DIR)/simv
$(BUILD_DIR)/simv: $(BUILD_DIR)/compile_rtl.sh
	cd $(BUILD_DIR);		\
	export SELCFG=$(ZOIX_SELCFG);		\
	export VERDI_HOME=$(VERDI_PATH); \
	./compile_rtl.sh;					\
	../elaborate_rtl.sh;

.PHONY: simulate
simulate: $(BUILD_DIR)/simv
	cd $(BUILD_DIR);		\
	./simv +fsdb+all=on +BOOTMODE=${ZOIX_BOOTMODE} +PRELMODE=${ZOIX_PRELMODE} +BINARY=${ZOIX_BINARY} -l simulate.log

.PHONY: simulate-gui
simulate-gui: $(BUILD_DIR)/simv
	cd $(BUILD_DIR);		\
	./simv +fsdb+all=on +BOOTMODE=${ZOIX_BOOTMODE} +PRELMODE=${ZOIX_PRELMODE} +BINARY=${ZOIX_BINARY} -gui -l simulate.log

.PHONY: faultsim
faultsim: $(BUILD_DIR)/fcm.dir
$(BUILD_DIR)/fcm.dir: $(BUILD_DIR)/simv $(ROOT_DIR)/fcm.tcl $(ROOT_DIR)/states.sff tb_cheshire_soc.sff
	cp -f $(ROOT_DIR)/fcm.tcl $(BUILD_DIR)/
	cp -f $(ROOT_DIR)/states.sff $(BUILD_DIR)/
	cp -f $(ROOT_DIR)/tb_cheshire_soc.sff $(BUILD_DIR)/
	cd $(BUILD_DIR); export FAULTSIM_TB=$(FAULTSIM_TB); export NUM_FAULT_SIM=$(NUM_FAULT_SIM); export BINARY=$(ZOIX_BINARY); export BOOTMODE=$(ZOIX_BOOTMODE); export PRELMODE=$(ZOIX_PRELMODE); $(FCM) -connect -tcl_script fcm.tcl

.PHONY: clean-zoix
clean-zoix:
	rm -rf $(BUILD_DIR)

tb_cheshire_soc.sff: $(ROOT_DIR)/tb_cheshire_soc.sff
$(ROOT_DIR)/tb_cheshire_soc.sff: $(ROOT_DIR)/fault.sff $(ROOT_DIR)/zoix.mk
	@cp -f $< $@
	sed -i "s|#faults|NA ~ (\"cycle1\" $(FAULT_START_CYCLE):$(FAULT_END_CYCLE)) { FLOP \"tb_cheshire_soc.fix.dut.i_core_cva6.gen_cva6_core[0].**\" }\n    #faults|" $@

#	sed -i "s|#faults|NA ~ (\"cycle1\" $(FAULT_START_CYCLE):$(FAULT_END_CYCLE)) { FLOP \"tb_cheshire_soc.fix.dut.i_core_wrap.**\" }\n    #faults|" $@
