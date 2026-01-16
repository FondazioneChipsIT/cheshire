#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "printf.h"

#define CSR_HENVCFG 0x60A
#define CSR_MENVCFG 0x30A
#define CSR_SENVCFG 0x10A
#define MSTATUS_MPP 0x00001800
#define CSR_MSECCFG 0x747

int main(void) {

    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    // Enable landing pad on machine mode
    asm volatile("csrw %0, %1"
                  :
                  : "i"(CSR_MSECCFG), "r"(1024)
                  : "memory");

    // Menv LP enable
    asm volatile("csrw %0, %1"
                  :
                  : "i"(CSR_MENVCFG), "r"(4)
                  : "memory");

    // HENV LP enable
    asm volatile("csrw %0, %1"
                  :
                  : "i"(CSR_HENVCFG), "r"(4)
                  : "memory");

    // SENV LP enable
    asm volatile("csrw %0, %1"
                  :
                  : "i"(CSR_SENVCFG), "r"(4)
                  : "memory");

    // test jalr
    asm volatile (
        "la   t1, lpad0       \n\t"
        "jalr ra, t1, 0       \n\t"
        "nop                  \n\t"
        "nop                  \n\t"
        "nop                  \n\t"

        "lpad0:               \n\t"
        ".word 0x00000017     \n\t"  // landing pad instruction
    );

    // test jr
    asm volatile (
        "la   t1, lpad1       \n\t"
        "jr   t1              \n\t"
        "nop                  \n\t"
        "nop                  \n\t"
        "nop                  \n\t"

        "lpad1:               \n\t"
        ".word 0x00000017     \n\t"  // landing pad instruction
    );

    // test jalr with label
    asm volatile (
        "lui   t2, 123    \n\t" // set landing pad label in the bits 31:12 of the x7 register
        "la   t1, lpad3   \n\t"
        "jalr ra, t1, 0   \n\t"
        "nop              \n\t"
        "nop              \n\t"
        "nop              \n\t"
        "nop              \n\t"

        "lpad3:           \n\t"
        ".word 0x0007B017 \n\t" // landing pad instruction
    );

    printf("Test succesfully finished\n\r");

    return 0;
}
