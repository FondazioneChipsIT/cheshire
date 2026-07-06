# #!/usr/bin/env bash
# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Cyril Koenig <cykoenig@iis.ee.ethz.ch>

TESTBENCH=tb_cheshire_soc
DUT_PATH="${TESTBENCH}.fix.dut.i_core_cva6.gen_cva6_core[0].i_cva6"

VCS_BIN="vcs"

# Set full path to c++ compiler.
if [ -z "${CXX_PATH}" ]; then
    if [ -z "${CXX}" ]; then
        CXX="g++"
    fi
    CXX_PATH=`which ${CXX}`
fi

# Set default VCS binary
#[[ -z "${VERDI_VERSION}" ]] && VERDI_VERSION=""
flags="+warn=noRT-NCMUCS +warn=noRT-MTOCMUCS "
#Set VCS compile args
flags+="-O2 "
flags+="-kdb -lca -sverilog -full64 -j8 -override_timescale=1ns/10ps "
flags+="+lint=TFIPC-L +lint=PCWM +warn=noCWUC +warn=noUII-L -l compile.log "
flags+="+vcs+fsdbon -debug_access+all "
#Set ZOIX compile args
flags+="+notimingchecks "
flags+="-debug_access+class -debug_access+pp -xlrm nettype_array -debug_region=lib+cell -force_list -debug_access+cbkd -debug_access+fwn "
flags+="-fsim "
#flags+="-fsim=dut:${TESTBENCH}.fix.dut.i_core_cva6 "
flags+="-fsim=dut:${DUT_PATH} "
flags+="-fsim=portfaults -fsim=class "

flags+="-cpp ${CXX_PATH} "
[[ -n "${SELCFG}" ]]   && flags+="-pvalue+SelectedCfg=${SELCFG} "

${VCS_BIN} ${flags} ../elfloader.cpp ${TESTBENCH}
