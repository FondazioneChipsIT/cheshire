#!/usr/bin/env bash

LOGFILE="ghdl_build.log"

# Save both stdout and stderr
exec > >(tee "$LOGFILE") 2>&1


###############################################################################
# Configuration
###############################################################################

STD="08"                # 93, 02, 08
TOP="noelv_chs_wrap"
OUT="build"

# Change to your preferred backend if needed
SYNTH_FORMAT="verilog"  # verilog, vhdl, raw, dot

###############################################################################
# Source lists
###############################################################################

GRLIB_FILES=(
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/stdlib/version.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/stdlib/config_types.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/designs/noelv-generic/grlib_config.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/stdlib/stdlib.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/stdlib/stdio.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/stdlib/testlib.vhd
#    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/util/util.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/amba.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/devices.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/defmst.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/apbctrl.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/apbctrlx.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/apbctrlsp.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/apbctrldp.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/apbctrl3p.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/apbctrl4p.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/ahbctrl.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/dma2ahb_pkg.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/dma2ahb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/ahbmst.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/amba/ahblitm2ahbm.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/modgen/multlib.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/modgen/leaves.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/sparc/sparc.vhd
#    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/sparc/sparc_disas.vhd
#    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/sparc/cpu_disas.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/riscv/riscv.vhd
#    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/riscv/riscv_disas.vhd
#    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/grlib/riscv/cpu_disas.vhd
)

TECHMAP_FILES=(
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/gencomp/gencomp.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/gencomp/netcomp.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/inferred/memory_inferred.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/inferred/mul_inferred.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/alltech/allclkgen.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/alltech/allddr.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/alltech/allmem.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/alltech/allmul.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/alltech/allpads.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/alltech/alltap.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/syncram.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/syncram_2p.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/syncramlb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/syncram64.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/techmult.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/memrwcol.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/tap.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/techbuf.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/techmap/maps/grgates.vhd
)

GAISLER_FILES=(
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/misc.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/rstgen.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/gptimer.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbram.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbdpram.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbtrace_mmb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbtrace_mb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbtrace.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/grgpio.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbstat.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/logan.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/apbps2.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/charrom_package.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/charrom.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/apbvga.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/svgactrl.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/grsysmon.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/gracectrl.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/grgpreg.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahb_mst_iface.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/grgprbank.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/grversion.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/apb3cdc.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbsmux.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/ahbmmux.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/misc/grtachom.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/uart.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/libdcom.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/apbuart.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/apbuart_16550.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/dcom.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/dcom_uart.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/uart/ahbuart.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/busif5_types.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/l5nv_shared.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_ic_dmaport.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_ic_busport.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_ic_ebp.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_ic.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_ahbs.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/tbufmemnv_mbus.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_trace.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_trace_ahb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/dmnv_reg_step.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/l5tsc.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/busif5x.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/busif5rdb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/busif5.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/tcmwrap5.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/cachemem5.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/l5nv/shared/snoopmem5.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/axi/axi.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/axi/ahb2axib.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/axi/ahb2axi4b.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/jtag/libjtagcom.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/jtag/jtag.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/jtag/ahbjtagrv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/jtag/jtagcomrv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/pkg/noelv_cfg_64.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/pkg/noelv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/pkg/noelv_cpu_cfg.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/pkg/nvnlconfig.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/utilnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/noelvtypes.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/noelvint.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/nvsupport.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/mmuconfig.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/bhtnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/btbnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/btbdmnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/rasnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/tbufmemnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/fputilnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/mul64.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/div64.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/regfile64sramnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/regfile64dffnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/alunv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/rvvi.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/iunv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/itracenv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/cctrl5nv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/mulfp.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/nanofpunv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/cpucorenvbc.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/cpucorenvb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/cpucorenv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/interrupt_file.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/imsic_int_files.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/core/fpsimutilnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/aclint/clint.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/aclint/clint_ahb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/aclint/aclint_ahb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/imsic/imsic_ahb.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/dm/dmnvint.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/dm/progbuf.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/dm/dmnvx.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/dm/dmnv.vhd
    ../../../hw/noelv/grlib-gpl-2025.2-b4298/lib/gaisler/noelv/subsys/noelvcpu.vhd
)

WORK_FILES=(
    ../../../hw/noelv/noelv_chs_wrap.vhd
    ../../../hw/noelv/jtag_tap_wrap.vhd
    ../memory_ihp130.vhd
)


###############################################################################
# Functions
###############################################################################

preprocess() {
    local in="$1"
    local out="$2"

    mkdir -p "$(dirname "$out")"

    awk '
    BEGIN { skip=0 }

    /(pragma|synopsys|synthesis).*translate_off/ {
        skip=1
        print ""
        next
    }

    /(pragma|synopsys|synthesis).*translate_on/ {
        skip=0
        print ""
        next
    }

    skip {
        print ""
        next
    }

    {
        print
    }
    ' "$in" > "$out"
}

analyze_library()
{
    local lib="$1"
    shift

    echo
    echo "===================================================="
    echo "Analyzing library: ${lib}"
    echo "===================================================="

    mkdir -p "${OUT}/${lib}"

    for file in "$@"; do
        echo "  $file"

        module=${file##*/}

        dst="${OUT}/preprocessed/${module}"
        preprocess "$file" "$dst"

        ghdl -a \
            -Pbuild/grlib \
            -Pbuild/techmap \
            -Pbuild/gaisler \
            -Pbuild/work \
            -frelaxed \
            -fexplicit \
            -fsynopsys \
            --std="${STD}" \
            --work="${lib}" \
            --workdir="${OUT}/${lib}" \
            "$dst"
    done
}

###############################################################################
# Clean
###############################################################################

rm -rf "${OUT}"
mkdir -p "${OUT}"

###############################################################################
# Analyze
###############################################################################

analyze_library grlib "${GRLIB_FILES[@]}"
analyze_library techmap "${TECHMAP_FILES[@]}"
analyze_library gaisler "${GAISLER_FILES[@]}"
analyze_library work "${WORK_FILES[@]}"

###############################################################################
# Elaborate
###############################################################################

echo
echo "===================================================="
echo "Elaborating ${TOP}"
echo "===================================================="

ghdl -e \
    -Pbuild/grlib \
    -Pbuild/techmap \
    -Pbuild/gaisler \
    -Pbuild/work \
    -frelaxed \
    --syn-binding \
    -fexplicit \
    -fsynopsys \
    --std="${STD}" \
    --work=work \
    --workdir="${OUT}/work" \
    "${TOP}"

###############################################################################
# Synthesize
###############################################################################

echo
echo "===================================================="
echo "Synthesizing ${TOP}"
echo "===================================================="

mkdir -p synth

ghdl --synth \
    -Pbuild/grlib \
    -Pbuild/techmap \
    -Pbuild/gaisler \
    -Pbuild/work \
    -frelaxed \
    --syn-binding \
    -fexplicit \
    -fsynopsys \
    --keep-hierarchy=yes \
    --no-formal \
    --out="${SYNTH_FORMAT}" \
    --std="${STD}" \
    --work=work \
    --workdir="${OUT}/work" \
    "${TOP}" \
    > "synth/${TOP}.v"

./postprocess.pl "synth/${TOP}.v" > "synth/${TOP}_post.v"

echo
echo "Done."
