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
    
    extern char dummy1_code_start, dummy1_code_end, dummy2_code_start, dummy2_code_end;

    uint32_t instructions[] = {0xf3000017, 0xf3000017, 
                                0x00100013, 0xda678013,
                                0xf3000017, 0x00200013, 
                                0xd9a78013, 0xf3000017, 
                                0x00300013, 0xd8e78013,
                                0xf3000017, 0xf3000017, 
                                0xd8270013, 0xf3000017,  
                                0xd7278013, 0xf3000017, 
                                0xd6678013};


    //---------------------------------------------------------------------------------------------//
    //--------------------------------------INSTR MODE TEST----------------------------------------//
    //---------------------------------------------------------------------------------------------//

    // Configure LSBs and MSBs of START_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_L_REG_OFFSET) = (uintptr_t)&dummy1_code_start;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_L_REG_OFFSET) = (uintptr_t)&dummy1_code_end;

    // Configure Snooper to log only instructions executed in M mode
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_M_MODE_BIT);

    // Set this bit to snoop from core 1 instead of core 0
    // set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_CORE_SELECT_BIT);

    // Configure Snooper Logging mode: Instr
    // Instr mode to log the opcode of every instruction
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRACE_MODE_OFFSET);

    // Enable RANGE_0 from CTRL register, this will enable the snooper to log the RANGE_0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_0_BIT);

    fence();

    asm volatile (
        "dummy1_code_start: \n\r"
        "auipc	zero,0xf3000 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "li	zero,1 \n\r"
        "addi	zero,a5,-602 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "li	zero,2 \n\r"
        "addi	zero,a5,-614 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "li	zero,3 \n\r"
        "addi	zero,a5,-626 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "addi	zero,a4,-638 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "addi	zero,a5,-654 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "dummy1_code_end: \n\r"
        "addi	zero,a5,-666 \n\r"
    );

    // Stop snooper logging
    clear_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_0_BIT);

    int base, last, new_base, new_last;

    base = *reg32(&__base_snprcfg, CFG_REGS_BASE_REG_OFFSET);
    last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    for(int i=base;i<=last;i=i+4) { // Instruction mode
        if (*reg32(&__base_snpr, i) != instructions[i/4])
            return 1; // return error in case the logged instruction is different from the expected instruction
    }

    //--------------------------------------------------------------------------------------------//
    //--------------------------------------ADDR MODE TEST----------------------------------------//
    //--------------------------------------------------------------------------------------------//

    // Configure LSBs and MSBs of START_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_L_REG_OFFSET) = (uintptr_t)&dummy2_code_start;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_L_REG_OFFSET) = (uintptr_t)&dummy2_code_end;

    // Configure Snooper Logging mode: Addr
    // Addr mode to log PC src, PC dst and ctr_type of branches and jumps
    clear_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRACE_MODE_OFFSET);


    //-------------------------------------TRIGGER INTERRUPT---------------------------------------//
    // This interrupt triggers when the snooper reads a committing instruction with PC=TRIGGER_PC0
    // The trigger interrupt resets the snooper ctrl register, this stops the snooper operation
    // allowing to read the execution trace without the risk of new instructions 
    // overwriting the instructions already stored in the buffer

    // Configure LSBs and MSBs of TRIGGER_PC0
    *reg32(&__base_snprcfg, CFG_REGS_TRIG_PC0_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_TRIG_PC0_L_REG_OFFSET) = (uintptr_t)&dummy2_code_end;
    // Enable trigger interrupt for PC0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRIG_PC_0_BIT);


    //------------------------------------WATERMARK INTERRUPT--------------------------------------//
    // Watermark interrupt can only be used in instruction mode
    // This interrupt triggers when the numbers of instructions stored in the buffer minus
    // the number of instructions previously read through AXI is higher than the watermark lvl
    // The interrupt is high as long as this condition is met and does not stop the snooper operation

    // Set watermark level to 10 instructions
    *reg32(&__base_snprcfg, CFG_REGS_WATERMARK_LEVEL_REG_OFFSET) = 0x0000000a; 
    // Enable watermark interrupt
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_WATERMARK_EN_BIT);


    // Enable RANGE_0 from CTRL register, this will enable the snooper to log the RANGE_0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_0_BIT);

    fence();

    asm volatile ("dummy2_code_start:");

    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_2_REG_OFFSET) = 2;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET) = 3;
    for (int i=0; i<(int) *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET); i++) {
        *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;  
    }

    asm volatile ("dummy2_code_end:");

    new_base = last + 4;
    new_last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    for(int i=new_base;i<new_last;i=i+20) { // Address mode
        if ((*reg32(&__base_snpr, i + 0x00) <= (uintptr_t)&dummy2_code_start) || (*reg32(&__base_snpr, i + 0x00) >= (uintptr_t)&dummy2_code_end))
            return 1; // return error in case the buffer contains a PC outside of the logging region
    }

    return 0;
}

