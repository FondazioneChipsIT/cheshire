// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "dif/snooper_test.h"

//#define INSTR
//#define CORE_1

void set_register_bit(void *base_addr, uint32_t reg_offset, uint32_t bit_position) {
    uint32_t reg_value = *reg32(base_addr, reg_offset);
    reg_value |= (1 << bit_position);
    *reg32(base_addr, reg_offset) = reg_value;
}

int main(void) {
    
    // Configure LSBs and MSBs of START_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_L_REG_OFFSET) = 0x10000228;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_L_REG_OFFSET) = 0x1000024e;

    // Configure Snooper to log only instrucitions executed in M mode
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_M_MODE_BIT);

    #ifdef CORE_1
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_CORE_SELECT_BIT);
    #endif

    // Configure Snooper Logging mode: Instr or Addr (default)
    // Instr mode to log all instructions opcodes
    // Addr mode to log PC src, PC dst and ctr_type of branches and jumps
    #ifdef INSTR
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRACE_MODE_OFFSET);
    #endif

    // Enable RANGE_0 from CTRL register, this will enable the snooper to log the RANGE_0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_0_BIT);

    // dummy code
    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_2_REG_OFFSET) = 2;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET) = 3;
    for (int i=0; i<(int) *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET); i++) {
          *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;  
    }

    int base, last;

    base = *reg32(&__base_snprcfg, CFG_REGS_BASE_REG_OFFSET);
    last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    #ifndef INSTR
    for(int i=base;i<=last;i=i+20) {
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i + 0x00); // read lsb 32bit of src PC
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i + 0x08); // read lsb 32bit of dst PC
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i + 0x10); // read ctr_type 32bit
    }
    #else
    for(int i=base;i<=last;i=i+4) {
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i); // read instr opcode 32bit 
    }
    #endif

    return 0;
}

