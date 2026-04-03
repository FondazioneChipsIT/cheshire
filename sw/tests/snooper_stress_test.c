#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "regs/snooper_regs.h"

void set_register_bit(void *base_addr, uint32_t reg_offset, uint32_t bit_position) {
    uint32_t reg_value = *reg32(base_addr, reg_offset);
    reg_value |= (1 << bit_position);
    *reg32(base_addr, reg_offset) = reg_value;
}

void clear_register_bit(void *base_addr, uint32_t reg_offset, uint32_t bit_position) {
    uint32_t reg_value = *reg32(base_addr, reg_offset);
    reg_value &= ~(1U << bit_position);
    *reg32(base_addr, reg_offset) = reg_value;
}

int main(void) {
    
    extern char dummy1_code_start, dummy1_code_end, dummy2_code_start, dummy2_code_end, dummy3_code_start, dummy3_code_end;

    int base, last, new_last, PC_DST_H, PC_DST_L, PC_SRC_L, PC_SRC_H, CTR_TYPE;

    //--------------------------------------------------------------------------------------------//
    //-----------------------------------ADDR MODE STRESS TEST------------------------------------//
    //--------------------------------------------------------------------------------------------//

    // Configure LSBs and MSBs of START_ADDRESS for RANGE_0, first logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_L_REG_OFFSET) = (uintptr_t)&dummy1_code_start;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_0, first logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_L_REG_OFFSET) = (uintptr_t)&dummy1_code_end;

    // Configure LSBs and MSBs of START_ADDRESS for RANGE_1, second logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_1_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_1_BASE_L_REG_OFFSET) = (uintptr_t)&dummy2_code_start;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_1, second logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_1_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_1_LAST_L_REG_OFFSET) = (uintptr_t)&dummy2_code_end;

    // Configure LSBs and MSBs of START_ADDRESS for RANGE_2, third logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_2_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_2_BASE_L_REG_OFFSET) = (uintptr_t)&dummy3_code_start;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_2, third logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_2_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_2_LAST_L_REG_OFFSET) = (uintptr_t)&dummy3_code_end;


    // Configure Snooper to log only instructions executed in M mode
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_M_MODE_BIT);

    // Configure Snooper Logging mode: Addr
    // Addr mode to log PC src, PC dst and ctr_type of branches and jumps
    clear_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRACE_MODE_OFFSET);

    // Set core halting level, core is halted if more than 800 unread address elements are present (or more than 4000 instruction elements)
    *reg32(&__base_snprcfg, CFG_REGS_HALT_LEVEL_REG_OFFSET) = 0x00003E80;
    // Enable core halting
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_CORE_HALT_EN_BIT);


    //------------------------------------WATERMARK INTERRUPT--------------------------------------//
    // This interrupt triggers when the numbers of elements stored in the buffer minus
    // the number of elements previously read through AXI is higher than the watermark level
    // The interrupt is high as long as this condition is met and does not stop the snooper operation
    // In instruction mode each element containts a single 32bit field (the instruction opcode)
    // thus the watermark level is increased by 1 for every element logged in instruction mode
    // In address mode each element is composed by 5 32bit fields (PC_SRC_L, PC_SRC_H, PC_DST_L, PC_DST_H, CTR_TYPE)
    // thus the watermark level is increased by 5 for every element logged in address mode

    // Set watermark level to 10 instructions (instruction mode) or 2 instruction addresses (address mode)
    *reg32(&__base_snprcfg, CFG_REGS_WATERMARK_LEVEL_REG_OFFSET) = 0x0000000a; 
    // Enable watermark interrupt
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_WATERMARK_EN_BIT);


    // Enable RANGE_0 from CTRL register, this will enable the snooper to log RANGE_0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_0_BIT);

    // Enable RANGE_1 from CTRL register, this will enable the snooper to log RANGE_1
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_1_BIT);

    // Enable RANGE_2 from CTRL register, this will enable the snooper to log RANGE_2
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_2_BIT);

    fence();

    asm volatile ("dummy1_code_start:");

    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    for (int i=0; i<300; i++) {
        if (*reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) != 0)
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    }

    asm volatile ("dummy1_code_end:");

    // Base is the index of the first valid element (it is incremented starting from 0 only when the buffer starts overwriting itself)
    base = *reg32(&__base_snprcfg, CFG_REGS_BASE_REG_OFFSET);
    // In address mode, last is the index of the last valid element + 20 (if no elements are valid this returns zero, if 1 element is valid this returns 20)
    last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    for (int i=base;i<last;i=i+20) {
        PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
        PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
        PC_DST_L = *reg32(&__base_snpr, i + 0x08);
        PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
        CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
        if ((PC_SRC_L <= (uintptr_t)&dummy1_code_start) || (PC_SRC_L >= (uintptr_t)&dummy1_code_end))
            return 1; // return error in case the buffer contains a PC outside of the logging region
    }

    asm volatile ("dummy2_code_start:");

    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    for (int i=0; i<300; i++) {
        if (*reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) != 0)
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    }

    asm volatile ("dummy2_code_end:");

    // In address mode, last is the index of the last valid element + 20 (if no elements are valid this returns zero, if 1 element is valid this returns 20)
    new_last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    if (new_last > last) { // Snooper didn't recirculate since last read
        for (int i=last;i<new_last;i=i+20) { // Keep reading normally
            PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
            PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
            PC_DST_L = *reg32(&__base_snpr, i + 0x08);
            PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
            CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
            if ((PC_SRC_L <= (uintptr_t)&dummy2_code_start) || (PC_SRC_L >= (uintptr_t)&dummy2_code_end))
                return 1; // return error in case the buffer contains a PC outside of the logging region
        }
    } else { // Snooper recirculated since last read
        // Keep reading the buffer until the end...
        for (int i=last;i<16380;i=i+20) {
            PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
            PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
            PC_DST_L = *reg32(&__base_snpr, i + 0x08);
            PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
            CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
            if ((PC_SRC_L <= (uintptr_t)&dummy2_code_start) || (PC_SRC_L >= (uintptr_t)&dummy2_code_end))
                return 1; // return error in case the buffer contains a PC outside of the logging region
        }
        for (int i=0;i<new_last;i=i+20) { // ...and then start again from the beginning
            PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
            PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
            PC_DST_L = *reg32(&__base_snpr, i + 0x08);
            PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
            CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
            if ((PC_SRC_L <= (uintptr_t)&dummy2_code_start) || (PC_SRC_L >= (uintptr_t)&dummy2_code_end))
                return 1; // return error in case the buffer contains a PC outside of the logging region
        }
    }

    asm volatile ("dummy3_code_start:");

    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    for (int i=0; i<3; i++) {
        if (*reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) != 0)
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    }

    asm volatile ("dummy3_code_end:");

    last = new_last;
    // In address mode, last is the index of the last valid element + 20 (if no elements are valid this returns zero, if 1 element is valid this returns 20)
    new_last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    if (new_last > last) { // Snooper didn't recirculate since last read
        for (int i=last;i<new_last;i=i+20) { // Keep reading normally
            PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
            PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
            PC_DST_L = *reg32(&__base_snpr, i + 0x08);
            PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
            CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
            if ((PC_SRC_L <= (uintptr_t)&dummy3_code_start) || (PC_SRC_L >= (uintptr_t)&dummy3_code_end))
                return 1; // return error in case the buffer contains a PC outside of the logging region
        }
    } else { // Snooper recirculated since last read
        // Keep reading the buffer until the end...
        for (int i=last;i<16380;i=i+20) {
            PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
            PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
            PC_DST_L = *reg32(&__base_snpr, i + 0x08);
            PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
            CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
            if ((PC_SRC_L <= (uintptr_t)&dummy3_code_start) || (PC_SRC_L >= (uintptr_t)&dummy3_code_end))
                return 1; // return error in case the buffer contains a PC outside of the logging region
        }
        for (int i=0;i<new_last;i=i+20) { // ...and then start again from the beginning
            PC_SRC_L = *reg32(&__base_snpr, i + 0x00);
            PC_SRC_H = *reg32(&__base_snpr, i + 0x04);
            PC_DST_L = *reg32(&__base_snpr, i + 0x08);
            PC_DST_H = *reg32(&__base_snpr, i + 0x0C);
            CTR_TYPE = *reg32(&__base_snpr, i + 0x10);
            if ((PC_SRC_L <= (uintptr_t)&dummy3_code_start) || (PC_SRC_L >= (uintptr_t)&dummy3_code_end))
                return 1; // return error in case the buffer contains a PC outside of the logging region
        }
    }

    // Reset circular buffer
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_CNT_RST_BIT);
    clear_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_CNT_RST_BIT);

    return 0;
}

