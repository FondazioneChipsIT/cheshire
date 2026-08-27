# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Max Wipfli <mwipfli@student.ethz.ch>
# Paul Scheffler <paulsc@iis.ee.ethz.ch>

BINARY ?= ./sw/tests/helloworld.spm.elf

CHS_VERILATOR_DIR ?= $(CHS_ROOT)/target/sim/verilator
RISCV_DBG_DIR = $(shell bender path riscv-dbg)

VERILATOR        ?= verilator

CHS_VERILATOR_THREADS   ?= 4
CHS_VERILATOR_UART_BAUD ?= 115200

# Silly Verilator warnings: these are perfectly valid and should not be warnings
VERILATOR_WNO   = -Wno-fatal -Wno-style \
	-Wno-BLKANDNBLK -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-WIDTHCONCAT -Wno-ASCRANGE -Wno-ENUMVALUE
VERILATOR_ARGS  ?= -j 0 -Wall $(VERILATOR_WNO) -timescale 1ns/1ps --no-timing

CHS_CORE ?= CVA6
ifeq ($(CHS_CORE),CVA6)
	VERILATOR_ARGS += -GSelectedCfg=0
else ifeq ($(CHS_CORE),C910)
	VERILATOR_ARGS += -GSelectedCfg=4
	CHS_BENDER_EXTRA_FLAGS += -t c910
else ifeq ($(CHS_CORE),SARGANTANA)
  	# SARG_BYPASS_LSQ mirrors QuestaSim's VLOG_ARGS (+define+SARG_BYPASS_LSQ)
  	# between QuestaSim and Verilator flows for valid performance comparisons.
  	VERILATOR_ARGS += -DSARG_BYPASS_LSQ -DSIM_COMMIT_LOG -GSelectedCfg=1
  	CHS_BENDER_EXTRA_FLAGS += -t sargantana
else ifeq ($(CHS_CORE),NOELV)
  	VERILATOR_ARGS += -GSelectedCfg=5
  	CHS_BENDER_EXTRA_FLAGS += -t noelv
endif

# UART baud rate
VERILATOR_ARGS += -GUartBaudRate=$(CHS_VERILATOR_UART_BAUD)

# Verilation optimizations
VERILATOR_ARGS += -O3 --x-assign fast --x-initial fast --noassert

# Disable common_cells assertions
VERILATOR_ARGS += -DASSERTS_OFF

# multithreading
VERILATOR_ARGS += --threads $(CHS_VERILATOR_THREADS)

# C++ Compiler Optimization
VERILATOR_ARGS += -CFLAGS "-O3" -CFLAGS "-march=native" -CFLAGS "-mtune=native"

# Use Clang (faster simulation than GCC)
VERILATOR_ARGS += --compiler clang -MAKEFLAGS "CC=clang" -MAKEFLAGS "CXX=clang++" -MAKEFLAGS "LINK=clang++"

# Link Time Optimization (LTO)
VERILATOR_ARGS += 

# Thread Profile-Guided Optimization (PGO)
# VERILATOR_ARGS += --prof-pgo
# VERILATOR_ARGS += profile.vlt

# Compiler Profile-Guided Optimization (PGO)
# VERILATOR_ARGS += -CFLAGS "-fprofile-generate" -CFLAGS "-fprofile-update=atomic" -LDFLAGS "-fprofile-generate" -LDFLAGS "-fprofile-update=atomic"
# VERILATOR_ARGS += -CFLAGS "-fprofile-use=../default.profdata"

# Profiling
# generates `gmon.out` that can be processed by `gprof` and then `verilator_profcfunc`
# VERILATOR_ARGS += --prof-cfuncs --report-unoptflat

# Tracing (FST): enabled for all cores except NOELV (SELCFG=5), which is VHDL-based
# and cannot be traced through this Verilator flow.
CHS_VERILATOR_TRACE_DEPTH ?= 5
ifneq ($(CHS_CORE),NOELV)
	VERILATOR_ARGS += --trace-fst --trace-structs --trace-depth $(CHS_VERILATOR_TRACE_DEPTH)
endif

VERILATOR_CXX_SRCS = $(CHS_VERILATOR_DIR)/sim/main.cpp \
	$(CHS_ROOT)/target/sim/src/elfloader.cpp \
	$(RISCV_DBG_DIR)/tb/remote_bitbang/remote_bitbang.c \
	$(RISCV_DBG_DIR)/tb/remote_bitbang/sim_jtag.c

VERILATOR_CONFIG = $(CHS_VERILATOR_DIR)/config.vlt

$(CHS_VERILATOR_DIR)/cheshire_soc.flist: $(CHS_ROOT)/Bender.yml
	$(BENDER) script verilator $(CHS_BENDER_RTL_FLAGS) $(CHS_BENDER_EXTRA_FLAGS) > $@

$(CHS_ROOT)/target/sim/verilator/obj_dir/Vcheshire_soc_wrapper: $(CHS_ROOT)/target/sim/verilator/cheshire_soc.flist $(VERILATOR_CXX_SRCS) $(VERILATOR_CONFIG)
	+cd $(CHS_VERILATOR_DIR) && stdbuf -oL $(VERILATOR) $(VERILATOR_ARGS) \
		-f $< $(VERILATOR_CXX_SRCS) $(VERILATOR_CONFIG) \
		--cc --exe --build --top-module cheshire_soc_wrapper 2>&1 | tee $(CHS_ROOT)/target/sim/verilator/verilator_build.log

chs-verilator-run: $(CHS_ROOT)/target/sim/verilator/obj_dir/Vcheshire_soc_wrapper
	stdbuf -oL $(CHS_ROOT)/target/sim/verilator/obj_dir/Vcheshire_soc_wrapper +BINARY=$(CHS_ROOT)/$(BINARY) 2>&1 | tee $(CHS_ROOT)/target/sim/verilator/verilator_run.log

$(CHS_ROOT)/target/sim/verilator/cheshire_soc.vlt: $(CHS_ROOT)/target/sim/verilator/obj_dir/Vcheshire_soc_wrapper
	@echo "#!/bin/sh" > $@
	@echo 'set -eu' >> $@
	@echo 'cd $$(dirname "$$0")' >> $@
	@echo 'taskset -c 0-$(shell expr $(CHS_VERILATOR_THREADS) - 1) ./obj_dir/Vcheshire_soc_wrapper "$$@"' >> $@
	@chmod +x $@

chs-generate-flist: $(CHS_VERILATOR_DIR)/cheshire_soc.flist
chs-verilator-build: $(CHS_ROOT)/target/sim/verilator/obj_dir/Vcheshire_soc_wrapper

CHS_VERILATOR_ALL += $(CHS_VERILATOR_DIR)/cheshire_soc.flist
CHS_VERILATOR_ALL += $(CHS_ROOT)/target/sim/verilator/obj_dir/Vcheshire_soc_wrapper
CHS_VERILATOR_ALL += chs-verilator-run

chs-verilator-all: $(CHS_VERILATOR_ALL)

CHS_PHONY += chs-verilator-all chs-verilator-build chs-verilator-run
