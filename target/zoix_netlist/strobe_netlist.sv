// strobe_netlist.sv
// VC Z01X observation points for the gate-level fault campaign on cheshire_wrap.
// Included in fixture_cheshire_wrap (target/zoix_netlist) under `ifdef VC_Z01X,
// same role as strobe.sv in the RTL fixture. Uses the fixture's clk and rst_n.
//
// Differences from the RTL version:
//  - no CVA6 packages or struct types: at gate level every struct is flattened
//    into plain bits, so the checks use plain logic vectors;
//  - multi-bit registers are read from the bus their flops drive when DC kept one
//    (e.g. i_regs.field_storage[]); otherwise they are rebuilt from flop outputs
//    (<flop_instance>.Q) with gen_concat.py;
//  - all names were checked against the netlist synthesized on 11 Nov 2026.
//
// Step 1: program-level checks FE, FR, FT and DMR detection CM/CE.
// Step 2: latent checks LR, LF, LS, LC, LM, LB (flop vectors from gen_latent_vectors.py)
//         and LI, LD (content of the I$ and D$ SRAM macros), at the end of the run.

localparam time TTest = 3ns;  // sample 3 ns after the rising clock edge

// ---------------------------------------------------------------------------
// Hierarchy (netlist names: generate scopes are flattened with underscores)
// ---------------------------------------------------------------------------
`define CHS     tb_cheshire_wrap.fix.dut.i_cheshire_soc
`define CLUSTER `CHS.gen_cva6_cores_0__i_core_cva6
`define CORE0   `CLUSTER.gen_cva6_core_0__i_cva6
`define CORE1   `CLUSTER.gen_cva6_core_1__i_cva6
`define HMR     `CLUSTER.gen_hmr_i_hmr_unit

// SoC registers: the scratch flops drive the internal bus i_regs.field_storage[],
// e.g. field_storage_reg_scratch__2__scratch__value__0_ .Q -> field_storage[416].
// LSB index of each scratch register in that bus:
`define REGS            `CHS.i_regs
// 16 scratch registers of 32 bits: scratch[k] = field_storage[(15-k)*32+31 : (15-k)*32]
`define SCRATCH0_LSB    480   // checked: scratch 0 = field_storage[511:480]
`define SCRATCH1_LSB    448   // checked: scratch 1 = field_storage[479:448]
`define SCRATCH2_LSB    416   // checked: scratch 2 = field_storage[447:416]

// DMR checker instance inside the HMR unit (checked in the netlist)
`define DMR_CHECKER     `HMR.gen_dmr_logic_gen_dmr_groups_0__dmr_core_checker_main

// ---------------------------------------------------------------------------
// FE: faulty exception (commit stage of each replica)
// exception_o [202:0] is the flattened exception_t {cause, tval, tval2, tinst, gva, valid}:
// valid is the last field, so it is bit 0.
// Checked in the netlist: instance commit_stage_i, exception_o[0] driven inside the
// module (NR2 U134) and connected to ex_commit[0] in the parent.
// ---------------------------------------------------------------------------
int   exception_cmp0, exception_cmp1;
logic exception_core0, exception_core1;

assign exception_core0 = `CORE0.commit_stage_i.exception_o[0];
assign exception_core1 = `CORE1.commit_stage_i.exception_o[0];

initial begin
  @(posedge rst_n);
  forever @(posedge clk) begin
    #(TTest);
    exception_cmp0 = $fs_compare(exception_core0);
    exception_cmp1 = $fs_compare(exception_core1);
    if (exception_cmp0 != 0)      $fs_set_status("FE", exception_core0);
    else if (exception_cmp1 != 0) $fs_set_status("FE", exception_core1);
  end
end

// ---------------------------------------------------------------------------
// FR: wrong program result (SoC scratch registers 0 and 1)
// Each scratch register is 32 contiguous bits of i_regs.field_storage[].
// ---------------------------------------------------------------------------
int          result_cmp0, result_cmp1;
logic [31:0] prog_result_core0, prog_result_core1;

assign prog_result_core0 = `REGS.field_storage[`SCRATCH0_LSB+31 : `SCRATCH0_LSB];
assign prog_result_core1 = `REGS.field_storage[`SCRATCH1_LSB+31 : `SCRATCH1_LSB];

initial begin
  @(posedge rst_n);
  forever @(posedge clk) begin
    #(TTest);
    result_cmp0 = $fs_compare(prog_result_core0);
    result_cmp1 = $fs_compare(prog_result_core1);
    if (result_cmp0 != 0)      $fs_drop_status("FR", prog_result_core0);
    else if (result_cmp1 != 0) $fs_drop_status("FR", prog_result_core1);
  end
end

// ---------------------------------------------------------------------------
// FT: timeout (program termination flag, scratch[2] bit 0)
// Declared a timeout if the faulty machine has not finished 10 cycles after
// the good machine.
// ---------------------------------------------------------------------------
int         prog_termination_cmp;
logic       prog_termination;
logic [3:0] timeout_cnt;

assign prog_termination = `REGS.field_storage[`SCRATCH2_LSB];

initial begin
  timeout_cnt = 4'd0;
  @(posedge rst_n);
  forever @(posedge clk) begin
    #(TTest);
    prog_termination_cmp = $fs_compare(prog_termination);
    if (prog_termination_cmp != 0) begin
      timeout_cnt = timeout_cnt + 1;
      if (timeout_cnt >= 10) $fs_drop_status("FT", prog_termination);
    end else begin
      timeout_cnt = 0;
    end
  end
end

// ---------------------------------------------------------------------------
// CM / CE: lockstep mismatch detected by the DMR checker
// In the netlist the checker's error_o is undriven. But bit 1506 of the compared
// struct is a constant-1 field, so check_o[1506] = 1 & ~error = ~error: DC drives it
// with a buffer of the full "no error" enable (BUF_20 U180: n3027 -> check_o[1506])
// and reuses it to gate the other check_o bits. So ~check_o[1506] is the full error.
// (Alternative, if ever needed: recompute it in the testbench from inp_a_i/inp_b_i,
//  counting only bit pairs that are known and different, (a ^ b) === 1'b1.)
// ---------------------------------------------------------------------------
int   dmr_cmp;
logic dmr_error;

assign dmr_error = ~`DMR_CHECKER.check_o[1506];

initial begin
  @(posedge rst_n);
  forever @(posedge clk) begin
    #(TTest);
    dmr_cmp = $fs_compare(dmr_error);
    if (dmr_cmp != 0) begin
      case ($fs_get_status())
        "FE":    $fs_drop_status("CE", dmr_error);  // exception, then detected
        default: $fs_drop_status("CM", dmr_error);  // detected by the DMR checker
      endcase
    end
  end
end

// ---------------------------------------------------------------------------
// Step 2: latent errors, checked once at the end of the simulation
// A latent error is a fault that did not change the program result, but left a
// wrong value in a state element: the good and the faulty machine end with
// different contents. Only checked if the fault is not already a program error.
// ---------------------------------------------------------------------------

// Scoreboard, CSRs and TLBs have no single bus in the netlist: their vectors are
// generated with
//   python3 gen_latent_vectors.py --netlist cheshire_wrap.v --config latent_vectors.cfg \
//       > strobe_netlist_latent.svh
// (rerun after every synthesis), which defines ls_*, lc_*, lm_*.
// Disabled by default: compile with +define+STROBE_GENERATED_VECTORS to enable them.
`ifdef STROBE_GENERATED_VECTORS
`include "strobe_netlist_latent.svh"
`endif

// Integer register files: DC kept the array as one bus, mem[2047:64]
// (register r, bit b at index 64*r+b; x0 is hardwired to zero and not stored).
// Checked in the netlist: mem_reg_31__63_ .Q -> mem[2047], mem_reg_1__0_ .Q -> mem[64].
`define RF0 `CORE0.issue_stage_i.i_issue_read_operands.gen_asic_regfile_i_ariane_regfile
`define RF1 `CORE1.issue_stage_i.i_issue_read_operands.gen_asic_regfile_i_ariane_regfile

logic [1983:0] lr_core0, lr_core1;
assign lr_core0 = `RF0.mem[2047:64];
assign lr_core1 = `RF1.mem[2047:64];

// Floating-point register files: same structure, bus mem[2047:0]
// (f0 is a real register, ZERO_REG_ZERO = 0, so all 32 registers are stored).
// Checked in the netlist: mem_reg_31__63_ .Q -> mem[2047], mem_reg_0__0_ .Q -> mem[0].
`define FRF0 `CORE0.issue_stage_i.i_issue_read_operands.float_regfile_gen_gen_asic_fp_regfile_i_ariane_fp_regfile
`define FRF1 `CORE1.issue_stage_i.i_issue_read_operands.float_regfile_gen_gen_asic_fp_regfile_i_ariane_fp_regfile

logic [2047:0] lf_core0, lf_core1;
assign lf_core0 = `FRF0.mem[2047:0];
assign lf_core1 = `FRF1.mem[2047:0];

// Branch target buffers: DC kept the array as one bus, gen_asic_btb_btb_q[2079:0]
// 32 entries (8 rows x 4 per fetch) of {valid, target_address[63:0]} = 65 bits:
// entry e = 4*row + col, target bit b at 65*e + b, valid at 65*e + 64.
// Checked in the netlist: ..._reg_7__3__target_address__63_ .Q -> [2078],
// ..._reg_0__0__target_address__0_ .Q -> [0].
`define BTB0 `CORE0.i_frontend.btb_gen_i_btb
`define BTB1 `CORE1.i_frontend.btb_gen_i_btb

logic [2079:0] lb_btb_core0, lb_btb_core1;
assign lb_btb_core0 = `BTB0.gen_asic_btb_btb_q[2079:0];
assign lb_btb_core1 = `BTB1.gen_asic_btb_btb_q[2079:0];

// Branch history tables (two-level BHT): DC kept the array as one bus, bht_q[2559:0]
// Entries of 20 bits: {valid, hist[2:0], saturation_counter[7:0][1:0]}, i.e.
// valid at 20*e + 19, hist at 20*e + 18..16, counters at 20*e + 15..0,
// with entry e = 4*row + col. Checked in the netlist: _reg_0__0__valid_ -> [19],
// _reg_0__1__valid_ -> [39], _reg_25__3__valid_ -> [2079]. The fault reports show
// rows up to 31 (bht_q_reg_31__3__...), so 32 rows x 4 = 128 entries = 2560 bits:
// check the declaration of bht_q in the netlist module.
`define BHT0 `CORE0.i_frontend.bht2lvl_gen_i_bht
`define BHT1 `CORE1.i_frontend.bht2lvl_gen_i_bht

logic [2559:0] lb_bht_core0, lb_bht_core1;
assign lb_bht_core0 = `BHT0.bht_q[2559:0];
assign lb_bht_core1 = `BHT1.bht_q[2559:0];

// Cache SRAM macros: content of the GF22 macro models (u0.mem_core_array).
// I$ and D$ memories sit in the core cluster, shared by both replicas.
`define ICMEM `CLUSTER.gen_icache_memwrap_0__i_icache_memwrap
`define DCMEM `CLUSTER.gen_dcache_memwrap_0__gen_dcache_memwrap_i_dcache_memwrap
// I$ tag: way W, cut C (2 cuts of 128x64)
`define IC_TAG(W, C) `ICMEM.gen_sram_``W``__tag_sram.genblk1_data_sram.gen_cut_0__i_tc_sram_wrapper.i_tc_sram.gen_256words_64bits_gen_multicut_logic_gen_128x64_cuts_``C``__i_cut.u0.mem_core_array
// I$ data: way W, 64-bit column L, cut C (2 columns x 2 cuts of 128x64)
`define IC_DATA(W, L, C) `ICMEM.gen_sram_``W``__data_sram.genblk1_data_sram.gen_cut_``L``__i_tc_sram_wrapper.i_tc_sram.gen_256words_64bits_gen_multicut_logic_gen_128x64_cuts_``C``__i_cut.u0.mem_core_array
// D$ directory: bank K, cut C (2 cuts of 128x48)
`define DC_DIR(K, C) `DCMEM.gen_dir_sram_``K``__dir_sram.gen_sram_i_sram.i_tc_sram.gen_256words_48bits_gen_multicut_logic_gen_128x48_cuts_``C``__i_cut.u0.mem_core_array
// D$ data: row R, cut C (2 cuts of 256x128)
`define DC_DATA(R, C) `DCMEM.gen_data_sram_row_``R``__gen_data_sram_col_0__data_sram.gen_sram_ram_i.i_tc_sram.gen_512words_128bits_gen_multicut_logic_gen_256x128_cuts_``C``__i_cut.u0.mem_core_array

// Drop a latent status if the faulty machine ends with a different value
`define LATENT(ST, SIG) if ($fs_compare(SIG) != 0) $fs_drop_status(ST, SIG);

final begin
  unique case ($fs_get_status())
    "FE", "FT", "FR": ;  // already a program error
    default: begin
      // Integer and floating-point register files
      `LATENT("LR", lr_core0)
      `LATENT("LR", lr_core1)
      `LATENT("LF", lf_core0)
      `LATENT("LF", lf_core1)
`ifdef STROBE_GENERATED_VECTORS
      // Scoreboard
      `LATENT("LS", ls_core0)
      `LATENT("LS", ls_core1)
      // CSRs
      `LATENT("LC", lc_core0)
      `LATENT("LC", lc_core1)
      // TLBs
      `LATENT("LM", lm_dtlb_core0)
      `LATENT("LM", lm_dtlb_core1)
      `LATENT("LM", lm_itlb_core0)
      `LATENT("LM", lm_itlb_core1)
`endif
      // Branch predictor
      `LATENT("LB", lb_btb_core0)
      `LATENT("LB", lb_btb_core1)
      `LATENT("LB", lb_bht_core0)
      `LATENT("LB", lb_bht_core1)
      // Instruction cache: 4 ways, tags (2 cuts) and data (2 columns x 2 cuts)
      `LATENT("LI", `IC_TAG(0, 0))  `LATENT("LI", `IC_TAG(0, 1))
      `LATENT("LI", `IC_DATA(0, 0, 0))  `LATENT("LI", `IC_DATA(0, 0, 1))  `LATENT("LI", `IC_DATA(0, 1, 0))  `LATENT("LI", `IC_DATA(0, 1, 1))
      `LATENT("LI", `IC_TAG(1, 0))  `LATENT("LI", `IC_TAG(1, 1))
      `LATENT("LI", `IC_DATA(1, 0, 0))  `LATENT("LI", `IC_DATA(1, 0, 1))  `LATENT("LI", `IC_DATA(1, 1, 0))  `LATENT("LI", `IC_DATA(1, 1, 1))
      `LATENT("LI", `IC_TAG(2, 0))  `LATENT("LI", `IC_TAG(2, 1))
      `LATENT("LI", `IC_DATA(2, 0, 0))  `LATENT("LI", `IC_DATA(2, 0, 1))  `LATENT("LI", `IC_DATA(2, 1, 0))  `LATENT("LI", `IC_DATA(2, 1, 1))
      `LATENT("LI", `IC_TAG(3, 0))  `LATENT("LI", `IC_TAG(3, 1))
      `LATENT("LI", `IC_DATA(3, 0, 0))  `LATENT("LI", `IC_DATA(3, 0, 1))  `LATENT("LI", `IC_DATA(3, 1, 0))  `LATENT("LI", `IC_DATA(3, 1, 1))
      // Data cache: directory (8 banks x 2 cuts) and data (4 rows x 2 cuts)
      `LATENT("LD", `DC_DIR(0, 0))  `LATENT("LD", `DC_DIR(0, 1))
      `LATENT("LD", `DC_DIR(1, 0))  `LATENT("LD", `DC_DIR(1, 1))
      `LATENT("LD", `DC_DIR(2, 0))  `LATENT("LD", `DC_DIR(2, 1))
      `LATENT("LD", `DC_DIR(3, 0))  `LATENT("LD", `DC_DIR(3, 1))
      `LATENT("LD", `DC_DIR(4, 0))  `LATENT("LD", `DC_DIR(4, 1))
      `LATENT("LD", `DC_DIR(5, 0))  `LATENT("LD", `DC_DIR(5, 1))
      `LATENT("LD", `DC_DIR(6, 0))  `LATENT("LD", `DC_DIR(6, 1))
      `LATENT("LD", `DC_DIR(7, 0))  `LATENT("LD", `DC_DIR(7, 1))
      `LATENT("LD", `DC_DATA(0, 0))  `LATENT("LD", `DC_DATA(0, 1))
      `LATENT("LD", `DC_DATA(1, 0))  `LATENT("LD", `DC_DATA(1, 1))
      `LATENT("LD", `DC_DATA(2, 0))  `LATENT("LD", `DC_DATA(2, 1))
      `LATENT("LD", `DC_DATA(3, 0))  `LATENT("LD", `DC_DATA(3, 1))
    end
  endcase
end

`undef RF0
`undef RF1
`undef FRF0
`undef FRF1
`undef BTB0
`undef BTB1
`undef BHT0
`undef BHT1
`undef ICMEM
`undef DCMEM
`undef IC_TAG
`undef IC_DATA
`undef DC_DIR
`undef DC_DATA
`undef LATENT
`undef CHS
`undef CLUSTER
`undef CORE0
`undef CORE1
`undef HMR
`undef REGS
`undef SCRATCH0_LSB
`undef SCRATCH1_LSB
`undef SCRATCH2_LSB
`undef DMR_CHECKER
