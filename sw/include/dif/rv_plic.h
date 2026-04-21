// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Cheshire PLIC driver
//
// A self-contained, header-only driver for the rv_plic peripheral  
// The hardware is the OT-derived `rv_plic` IP from the `opentitan_peripherals` repository, instantiated
// in `cheshire_soc.sv`.
//
//
// Source count:
//   - 60 internal Cheshire sources (cheshire_int_intr_t, including snooper)
//   - 32 external sources (CarfieldNumExtIntrs = 32 in the package),
//     packed above them in cheshire_intr_t.  The mapping is:
//
//     PLIC source  Signal
//     -----------  ----------------------------------------
//      0 .. 59     Internal Cheshire (cheshire_int_intr_t)
//     60           pulpcl_eoc
//     61           pulpcl_hostd_mbox_intr  (PULP cluster  -> hostd)
//     62           spatzcl_hostd_mbox_intr (Spatz cluster -> hostd)
//     63           safed_hostd_mbox_intr   (Safety island -> hostd)
//     64           secd_hostd_mbox_intr    (Security island -> hostd)
//     65           l2_ecc_err
//     66 .. 82     car_periph_intrs[0..16] (timers, WDT, CAN, ETH)
//     83 .. 91     unused (tied 0)
//
//   NOTE: NumSrc and NumTarget are auto-generated into rv_plic_regs.h by
//   `make car-all`.  This driver derives its constants from that header,
//   so rebuilding ensures correct values are always used.
//
// Register map (rv_plic instance, NumSrc=92, NumTarget=6):
//   (Authoritative values from the auto-generated rv_plic_regs.h)
//
//   Offset range         Description
//   -------------------- --------------------------------------------------
//   0x0000 .. 0x016C     Priority registers  (1 word / source, 92 sources)
//   0x1000 .. 0x1008     Interrupt-Pending   (1 bit / source, 3 words)
//   0x2000 .. 0x2008     IE[target=0]        (1 bit / source, 3 words)
//   0x2080 .. 0x2088     IE[target=1]        (1 bit / source, 3 words)
//   0x2100 .. 0x2108     IE[target=2]
//   0x2180 .. 0x2188     IE[target=3]
//   0x2200 .. 0x2208     IE[target=4]
//   0x2280 .. 0x2288     IE[target=5]
//   0x200000             Threshold[target=0]
//   0x200004             CC[target=0]        (Claim / Complete)
//   0x201000 .. 0x205004 Threshold[target=1..5] / CC[target=1..5]
//   0x3FFFFF8            MSIP[target=0]      (Software interrupt)
//
// PLIC parameters (rv_plic instance, from rv_plic_regs.h):
//   NUM_SRC    = 92   interrupt sources (60 internal + 32 external)
//   NUM_TARGET = 6    targets (harts)
//   MAX_PRIO   = 7    (3-bit priority field)

#pragma once

#include "rv_plic_regs.h"
#include <stdint.h>

// ---------------------------------------------------------------------------
// Instantiation parameters
// ---------------------------------------------------------------------------

/**
 * Total number of interrupt sources in this rv_plic instantiation.
 *
 * The interrupt vector (cheshire_intr_t) is 92 bits wide:
 *   - 60 internal Cheshire sources (cheshire_int_intr_t in cheshire_pkg.sv,
 *     which includes the snooper fields)
 *   - 32 external sources (CarfieldNumExtIntrs = 32 in the package),
 *     packed above the internal sources
 *
 * The PLIC hardware must be generated with NumSrc=92 (by regenerating
 * rv_plic_reg_pkg.sv via reggen).  The version shipped in
 * The authoritative value is `RV_PLIC_PARAM_NUM_SRC` from the
 * auto-generated `rv_plic_regs.h` (regenerated via `make car-all`).
 *
 * Important: PLIC source IDs are derived from the bit index in
 * cheshire_intr_t.  See the file header for the full source mapping.
 */
#define CHS_PLIC_NUM_SRC     ((uint32_t)RV_PLIC_PARAM_NUM_SRC)

/**
 * Number of interrupt targets (harts) in the rv_plic.
 * Matches `RV_PLIC_PARAM_NUM_TARGET` from the auto-generated `rv_plic_regs.h`.
 * Target 0 = CVA6 machine-mode hart 0 (host domain).
 * Targets 1..5 map to additional harts in other domains.
 */
#define CHS_PLIC_NUM_TARGET  ((uint32_t)RV_PLIC_PARAM_NUM_TARGET)

/**
 * Maximum priority value. Derived from `RV_PLIC_PARAM_PRIO_WIDTH` in the
 * auto-generated `rv_plic_regs.h` (3-bit field → range 0 (off) to 7 (highest)).
 */
#define CHS_PLIC_MAX_PRIO    ((1u << RV_PLIC_PARAM_PRIO_WIDTH) - 1u)

// ---------------------------------------------------------------------------
// Interrupt source IDs (hardware wiring, derived from SoC package)
// ---------------------------------------------------------------------------
// Sources 0..59 are internal Cheshire peripherals (cheshire_int_intr_t).
// Sources 60..91 are external peripherals (chs_ext_intrs).
// Source 0 (cheshire_int_intr_t.zero) is always 0 — do not enable it.

/** PULP integer cluster end-of-compute signal. */
#define CHS_PLIC_IRQ_PULPCL_EOC          60u
/** PULP integer cluster → host-domain mailbox interrupt. */
#define CHS_PLIC_IRQ_PULPCL_MBOX_HOSTD  61u
/** Spatz FP cluster → host-domain mailbox interrupt. */
#define CHS_PLIC_IRQ_SPATZCL_MBOX_HOSTD 62u
/** Safety island → host-domain mailbox interrupt. */
#define CHS_PLIC_IRQ_SAFED_MBOX_HOSTD   63u
/** Security island → host-domain mailbox interrupt. */
#define CHS_PLIC_IRQ_SECD_MBOX_HOSTD    64u
/** L2 ECC error interrupt. */
#define CHS_PLIC_IRQ_L2_ECC_ERR          65u
// Sources 66..82: car_periph_intrs (advanced timers, system timers,
//                 watchdog timers, CAN, Ethernet).
// Sources 83..91: unused (tied to 0).

// ---------------------------------------------------------------------------
// Register offset macros
// ---------------------------------------------------------------------------

/**
 * Priority register offset for interrupt source @p irq.
 * Layout: one 32-bit word per source starting at offset 0x0.
 */
#define CHS_PLIC_PRIO_OFFSET(irq) \
    ((uintptr_t)(irq) * 4u)

/**
 * Interrupt-Pending register offset containing the pending bit for @p irq.
 * Layout: 1 bit per source, packed into 32-bit words at base 0x1000.
 */
#define CHS_PLIC_IP_OFFSET(irq) \
    (0x1000u + ((uintptr_t)(irq) / 32u) * 4u)

/**
 * Stride in bytes between the IE register banks of consecutive targets.
 * Each target occupies 0x80 bytes of enable registers, as per the RISC-V
 * PLIC specification and confirmed by the rv_plic register file
 * (IE0_0=0x2000, IE1_0=0x2080).
 */
#define CHS_PLIC_IE_TARGET_STRIDE  0x80u

/**
 * Interrupt-Enable register offset for source @p irq and target @p target.
 * Layout: target T starts at 0x2000 + T * 0x80; within each bank the bits
 * are packed into 32-bit words (1 bit per source).
 */
#define CHS_PLIC_IE_OFFSET(target, irq) \
    (0x2000u + (uintptr_t)(target) * CHS_PLIC_IE_TARGET_STRIDE \
             + ((uintptr_t)(irq) / 32u) * 4u)

/**
 * Stride in bytes between the Threshold/CC register pairs of consecutive
 * targets. THRESHOLD0=0x200000, THRESHOLD1=0x201000 → stride = 0x1000.
 */
#define CHS_PLIC_TARGET_UPPER_STRIDE  0x1000u

/**
 * Priority Threshold register offset for @p target.
 * An interrupt is only forwarded when its priority is strictly greater than
 * this threshold. Setting threshold to 0 allows all priorities to pass.
 */
#define CHS_PLIC_THRESHOLD_OFFSET(target) \
    (0x200000u + (uintptr_t)(target) * CHS_PLIC_TARGET_UPPER_STRIDE)

/**
 * Claim/Complete register offset for @p target.
 * Reading this register claims the highest-priority pending interrupt;
 * writing the returned source ID back completes service.
 */
#define CHS_PLIC_CC_OFFSET(target) \
    (0x200004u + (uintptr_t)(target) * CHS_PLIC_TARGET_UPPER_STRIDE)

/**
 * Machine Software Interrupt Pending register offset for @p target.
 * Writing 1 asserts a software interrupt for the target hart.
 * Base is `RV_PLIC_MSIP0_REG_OFFSET` from the generated regs header.
 */
#define CHS_PLIC_MSIP_OFFSET(target) \
    ((uintptr_t)RV_PLIC_MSIP0_REG_OFFSET + (uintptr_t)(target) * 4u)

// ---------------------------------------------------------------------------
// Return codes
// ---------------------------------------------------------------------------

/** Operation completed successfully. */
#define CHS_PLIC_OK       0

/** Bad argument (NULL pointer or out-of-range value). */
#define CHS_PLIC_ERR_ARG  (-1)

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Interrupt source identifier.
 * Valid range: 0 (reserved / "no interrupt") .. CHS_PLIC_NUM_SRC - 1.
 */
typedef uint32_t chs_plic_irq_id_t;

/**
 * Interrupt target (hart) identifier.
 * Valid range: 0 .. CHS_PLIC_NUM_TARGET - 1.
 */
typedef uint32_t chs_plic_target_t;

// ---------------------------------------------------------------------------
// Internal helper: volatile 32-bit MMIO register pointer
// ---------------------------------------------------------------------------

static inline volatile uint32_t *_chs_plic_reg(void *base, uintptr_t offset) {
    return (volatile uint32_t *)((uint8_t *)base + offset);
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

/**
 * Reset the PLIC to a clean state.
 *
 * Clears all source priority registers, all interrupt-enable registers, all
 * threshold registers, and all software-interrupt registers. The
 * Claim/Complete register is intentionally left untouched — the previous
 * owner of any in-flight claim is responsible for completing it.
 *
 * @param base  MMIO base address of the PLIC peripheral (e.g. &__base_plic).
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG if @p base is NULL.
 */
static inline int chs_plic_reset(void *base) {
    if (!base) return CHS_PLIC_ERR_ARG;

    /* Clear all priority registers. */
    for (chs_plic_irq_id_t i = 0; i < CHS_PLIC_NUM_SRC; ++i)
        *_chs_plic_reg(base, CHS_PLIC_PRIO_OFFSET(i)) = 0u;

    /* Clear all target-scoped registers. */
    uint32_t num_ie_words = (CHS_PLIC_NUM_SRC + 31u) / 32u;
    for (chs_plic_target_t t = 0; t < CHS_PLIC_NUM_TARGET; ++t) {
        /* IE words for this target */
        for (uint32_t w = 0; w < num_ie_words; ++w)
            *_chs_plic_reg(base,
                0x2000u + t * CHS_PLIC_IE_TARGET_STRIDE + w * 4u) = 0u;
        /* Threshold */
        *_chs_plic_reg(base, CHS_PLIC_THRESHOLD_OFFSET(t)) = 0u;
        /* Software interrupt */
        *_chs_plic_reg(base, CHS_PLIC_MSIP_OFFSET(t)) = 0u;
    }

    return CHS_PLIC_OK;
}

/**
 * Set the priority of an interrupt source.
 *
 * The PLIC only forwards an interrupt to a target when its priority is
 * strictly greater than the target's threshold. Setting priority to 0
 * effectively masks the source globally.
 *
 * @param base      MMIO base address of the PLIC peripheral.
 * @param irq       Interrupt source identifier (must be < CHS_PLIC_NUM_SRC).
 * @param priority  Priority value in the range [0, CHS_PLIC_MAX_PRIO].
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_irq_set_priority(void *base,
                                             chs_plic_irq_id_t irq,
                                             uint32_t priority) {
    if (!base || irq >= CHS_PLIC_NUM_SRC || priority > CHS_PLIC_MAX_PRIO)
        return CHS_PLIC_ERR_ARG;
    *_chs_plic_reg(base, CHS_PLIC_PRIO_OFFSET(irq)) = priority;
    return CHS_PLIC_OK;
}

/**
 * Enable or disable an interrupt source for a given target.
 *
 * Performs a read-modify-write on the appropriate IE word to set or clear
 * the single enable bit for @p irq without disturbing other sources.
 *
 * @param base    MMIO base address of the PLIC peripheral.
 * @param irq     Interrupt source identifier.
 * @param target  Target (hart) identifier.
 * @param enable  Non-zero to enable the interrupt; zero to disable it.
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_irq_set_enabled(void *base,
                                            chs_plic_irq_id_t irq,
                                            chs_plic_target_t target,
                                            int enable) {
    if (!base || irq >= CHS_PLIC_NUM_SRC || target >= CHS_PLIC_NUM_TARGET)
        return CHS_PLIC_ERR_ARG;

    volatile uint32_t *reg = _chs_plic_reg(base, CHS_PLIC_IE_OFFSET(target, irq));
    uint32_t bit = 1u << (irq % 32u);

    if (enable)
        *reg |= bit;
    else
        *reg &= ~bit;

    return CHS_PLIC_OK;
}

/**
 * Query whether an interrupt source is currently enabled for a target.
 *
 * @param base     MMIO base address of the PLIC peripheral.
 * @param irq      Interrupt source identifier.
 * @param target   Target (hart) identifier.
 * @param enabled  Output: set to 1 if enabled, 0 if disabled.
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_irq_get_enabled(void *base,
                                            chs_plic_irq_id_t irq,
                                            chs_plic_target_t target,
                                            int *enabled) {
    if (!base || irq >= CHS_PLIC_NUM_SRC || target >= CHS_PLIC_NUM_TARGET
            || !enabled)
        return CHS_PLIC_ERR_ARG;

    uint32_t reg = *_chs_plic_reg(base, CHS_PLIC_IE_OFFSET(target, irq));
    *enabled = (int)((reg >> (irq % 32u)) & 1u);
    return CHS_PLIC_OK;
}

/**
 * Query whether an interrupt source is currently pending.
 *
 * The IP registers are read-only and reflect the level-triggered interrupt
 * state of each source. A source's pending bit is set by the PLIC when a
 * qualifying interrupt edge/level is detected and cleared when the interrupt
 * is claimed.
 *
 * @param base     MMIO base address of the PLIC peripheral.
 * @param irq      Interrupt source identifier.
 * @param pending  Output: set to 1 if the interrupt is pending, 0 otherwise.
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_irq_is_pending(void *base,
                                           chs_plic_irq_id_t irq,
                                           int *pending) {
    if (!base || irq >= CHS_PLIC_NUM_SRC || !pending)
        return CHS_PLIC_ERR_ARG;

    uint32_t reg = *_chs_plic_reg(base, CHS_PLIC_IP_OFFSET(irq));
    *pending = (int)((reg >> (irq % 32u)) & 1u);
    return CHS_PLIC_OK;
}

/**
 * Set the priority threshold for a target.
 *
 * The PLIC only asserts an external interrupt to the target hart when the
 * pending interrupt's priority is strictly greater than this threshold.
 * Threshold 0 allows all enabled interrupts through.
 *
 * @param base       MMIO base address of the PLIC peripheral.
 * @param target     Target (hart) identifier.
 * @param threshold  Threshold value in the range [0, CHS_PLIC_MAX_PRIO].
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_target_set_threshold(void *base,
                                                 chs_plic_target_t target,
                                                 uint32_t threshold) {
    if (!base || target >= CHS_PLIC_NUM_TARGET || threshold > CHS_PLIC_MAX_PRIO)
        return CHS_PLIC_ERR_ARG;
    *_chs_plic_reg(base, CHS_PLIC_THRESHOLD_OFFSET(target)) = threshold;
    return CHS_PLIC_OK;
}

/**
 * Claim the highest-priority pending interrupt for a target.
 *
 * Reads the target's Claim/Complete (CC) register. The PLIC returns the
 * source ID of the highest-priority pending interrupt that is both enabled
 * for the target and has priority above the threshold. A return value of 0
 * means no interrupt was pending.
 *
 * @p chs_plic_irq_complete() must be called with the returned @p irq_id
 * after the interrupt has been serviced.
 *
 * @param base    MMIO base address of the PLIC peripheral.
 * @param target  Target (hart) identifier.
 * @param irq_id  Output: claimed interrupt source ID (0 = no interrupt).
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_irq_claim(void *base,
                                      chs_plic_target_t target,
                                      chs_plic_irq_id_t *irq_id) {
    if (!base || target >= CHS_PLIC_NUM_TARGET || !irq_id)
        return CHS_PLIC_ERR_ARG;
    *irq_id = *_chs_plic_reg(base, CHS_PLIC_CC_OFFSET(target));
    return CHS_PLIC_OK;
}

/**
 * Complete a previously claimed interrupt.
 *
 * Writes @p irq_id back to the CC register to signal the PLIC that the
 * interrupt has been handled. After this call, the PLIC can reassert an
 * interrupt for the same source if the trigger condition persists.
 *
 * @param base    MMIO base address of the PLIC peripheral.
 * @param target  Target (hart) identifier.
 * @param irq_id  Interrupt source ID previously obtained from
 *                chs_plic_irq_claim().
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_irq_complete(void *base,
                                         chs_plic_target_t target,
                                         chs_plic_irq_id_t irq_id) {
    if (!base || target >= CHS_PLIC_NUM_TARGET)
        return CHS_PLIC_ERR_ARG;
    *_chs_plic_reg(base, CHS_PLIC_CC_OFFSET(target)) = irq_id;
    return CHS_PLIC_OK;
}

/**
 * Assert or deassert the machine software interrupt for a target.
 *
 * This can be used to trigger an inter-processor interrupt (IPI) between
 * harts. The receiving hart must have MSIP enabled in its mie CSR.
 *
 * @param base    MMIO base address of the PLIC peripheral.
 * @param target  Target (hart) identifier.
 * @param assert  Non-zero to assert, zero to deassert the software interrupt.
 * @return CHS_PLIC_OK, or CHS_PLIC_ERR_ARG on invalid input.
 */
static inline int chs_plic_software_irq_set(void *base,
                                             chs_plic_target_t target,
                                             int assert) {
    if (!base || target >= CHS_PLIC_NUM_TARGET)
        return CHS_PLIC_ERR_ARG;
    *_chs_plic_reg(base, CHS_PLIC_MSIP_OFFSET(target)) = assert ? 1u : 0u;
    return CHS_PLIC_OK;
}
