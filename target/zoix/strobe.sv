// Copyright 2025 ETH Zurich and University of Bologna.
// Proprietary, not for release
    import ariane_pkg::*;
    localparam time TTest = 3ns;
    
    localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(gen_cva6_cfg(DutCfg));

    localparam type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
      // address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
    };

    localparam type branchpredict_sbe_t = struct packed {
      cf_t                     cf;               // type of control flow prediction
      logic [CVA6Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    }; 

    localparam type jvt_t = struct packed {
      logic [CVA6Cfg.XLEN-7:0] base;
      logic [5:0] mode;
    };

    localparam type  satp_t = struct packed {
    logic [CVA6Cfg.ModeW-1:0] mode;
    logic [CVA6Cfg.ASIDW-1:0] asid;
    logic [CVA6Cfg.PPNW-1:0]  ppn;
    };

    localparam type hgatp_t =  struct packed {
    logic [CVA6Cfg.ModeW-1:0] mode;
    logic [1:0]               warl0;
    logic [CVA6Cfg.VMIDW-1:0] vmid;
    logic [CVA6Cfg.PPNW-1:0]  ppn;
    };

    localparam HYP_EXT = CVA6Cfg.RVH ? 1 : 0;

    localparam type tag_t = struct packed {
    logic [CVA6Cfg.ASID_WIDTH-1:0] asid;
    logic [CVA6Cfg.VMID_WIDTH-1:0] vmid;
    // VPN is:
    // [0] -> VPN0
    // [1] -> VPN1
    // [2] -> VPN2
    // [3] -> 2-bit supplementary PPN2 in case of GPA
    logic [CVA6Cfg.PtLevels+HYP_EXT-1:0][(CVA6Cfg.VpnLen/CVA6Cfg.PtLevels)-1:0] vpn;
    logic [CVA6Cfg.PtLevels-2:0][HYP_EXT:0] is_page;
    logic [HYP_EXT*2:0] v_st_enbl;  // v_i, g-stage enabled, s-stage enabled
    logic valid;
    };

    localparam type pte_cva6_t = struct packed {
    logic [9:0] reserved;
    logic [CVA6Cfg.PPNW-1:0] ppn;  // PPN length for
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
    };

    localparam type content_t = struct packed {
        pte_cva6_t pte;   // S or VS-stage Page Table Entry structure
        pte_cva6_t gpte;  // G-stage Page Table Entry structure
    };

    localparam type scoreboard_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] pc;  // PC of instruction
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;      // this can potentially be simplified, we could index the scoreboard entry
      // with the transaction id in any case make the width more generic
      fu_t fu;  // functional unit to use
      fu_op op;  // operation to perform in each functional unit
      logic [REG_ADDR_SIZE-1:0] rs1;  // register source address 1
      logic [REG_ADDR_SIZE-1:0] rs2;  // register source address 2
      logic [REG_ADDR_SIZE-1:0] rd;  // register destination address
      logic [CVA6Cfg.XLEN-1:0] result;  // for unfinished instructions this field also holds the immediate,
      // for unfinished floating-point that are partly encoded in rs2, this field also holds rs2
      // for unfinished floating-point fused operations (FMADD, FMSUB, FNMADD, FNMSUB)
      // this field holds the address of the third operand from the floating-point register file
      logic valid;  // is the result valid
      logic use_imm;  // should we use the immediate as operand b?
      logic use_zimm;  // use zimm as operand a
      logic use_pc;  // set if we need to use the PC as operand a, PC from exception
      exception_t ex;  // exception has occurred
      branchpredict_sbe_t bp;  // branch predict scoreboard data structure
      logic                     is_compressed; // signals a compressed instructions, we need this information at the commit stage if
                                               // we want jump accordingly e.g.: +4, +2
      logic is_macro_instr;  // is an instruction executed as predefined sequence of instructions called macro definition
      logic is_last_macro_instr;  // is last decoded 32bit instruction of macro definition
      logic is_double_rd_macro_instr;  // is double move decoded 32bit instruction of macro definition
      logic vfp;  // is this a vector floating-point instruction?
      logic is_zcmt;  //is a zcmt instruction
    };
    
    // this is the FIFO struct of the issue queue
    localparam type sb_mem_t = struct packed {
    logic issued;  // this bit indicates whether we issued this instruction e.g.: if it is valid
    logic cancelled;  // this instruction was cancelled (speculative scoreboard)
    logic is_rd_fpr_flag;  // redundant meta info, added for speed
    scoreboard_entry_t sbe;  // this is the score board entry we will send to ex
    };

    localparam clWidth = (CVA6Cfg.DCACHE_LINE_WIDTH / CVA6Cfg.XLEN)*CVA6Cfg.XLEN;
    localparam clOffsetWidth = $clog2(clWidth / 8);
    localparam setWidth = $clog2(CVA6Cfg.DCACHE_NUM_WORDS);
    localparam nlineWidth = CVA6Cfg.PLEN - clOffsetWidth;
    localparam tagWidth = nlineWidth - setWidth;

    localparam type hpdcache_tag_t = logic [tagWidth-1:0]; 

    typedef struct packed {
        //  Cacheline state
        //  Encoding: {valid, wb, dirty, fetch}
        //            {0,X,X,0}: Invalid
        //            {0,X,X,1}: Invalid and Fetching
        //            {1,X,X,1}: Valid and Fetching (cacheline being replaced is accessible)
        //            {1,0,0,0}: Write-through
        //            {1,1,0,0}: Write-back (clean)
        //            {1,1,1,0}: Write-back (dirty)
        //  {{{
        logic valid; //  valid cacheline
        logic wback; //  cacheline in write-back mode
        logic dirty; //  cacheline is locally modified (memory is obsolete)
        logic fetch; //  cacheline is reserved for a new cacheline being fetched
        //  }}}

        //  Cacheline address tag
        //  {{{
        hpdcache_tag_t tag;
        //  }}}
    } hpdcache_dir_entry_t;

    function int unsigned __minu(int unsigned x, int unsigned y);
        return x < y ? x : y;
    endfunction

    function int unsigned __maxu(int unsigned x, int unsigned y);
        return y < x ? x : y;
    endfunction

    localparam int unsigned HPDCACHE_DIR_RAM_WIDTH = $bits(hpdcache_dir_entry_t);
    localparam int unsigned HPDCACHE_DIR_RAM_ADDR_WIDTH = $clog2(CVA6Cfg.DCACHE_NUM_WORDS);
    localparam int unsigned HPDCACHE_DATA_RAM_ENTR_PER_SET = (CVA6Cfg.DCACHE_LINE_WIDTH / CVA6Cfg.XLEN)/
                                                             (__maxu(CVA6Cfg.AxiDataWidth / CVA6Cfg.XLEN, userCfg.reqWords));
    localparam int unsigned HPDCACHE_DATA_RAM_DEPTH = CVA6Cfg.DCACHE_NUM_WORDS*
                                                      HPDCACHE_DATA_RAM_ENTR_PER_SET;

    localparam int unsigned HPDCACHE_DATA_RAM_WIDTH = (__minu(CVA6Cfg.DCACHE_SET_ASSOC, 128 / CVA6Cfg.XLEN))*CVA6Cfg.XLEN;
    localparam int unsigned HPDCACHE_DATA_RAM_ADDR_WIDTH = $clog2(HPDCACHE_DATA_RAM_DEPTH);

    localparam NUM_WORDS_HPD_DIR = 2 ** HPDCACHE_DIR_RAM_ADDR_WIDTH;
    localparam NUM_WORDS_HPD_DATA = 2 ** HPDCACHE_DATA_RAM_ADDR_WIDTH;
    localparam DCACHE_DATA_WIDTH = HPDCACHE_DATA_RAM_WIDTH;
    localparam DCACHE_TAG_WIDTH = HPDCACHE_DIR_RAM_WIDTH;

    localparam NR_ROWS_BTB = CVA6Cfg.BTBEntries / CVA6Cfg.INSTR_PER_FETCH;
    localparam NR_ROWS_BHT = CVA6Cfg.BHTEntries / CVA6Cfg.INSTR_PER_FETCH;

    localparam type btb_prediction_t = struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] target_address;
    };

    localparam ADDR_WIDTH = 5;
    localparam NUM_WORDS = 2 ** ADDR_WIDTH;

   // initial begin
     //   $fs_inject;
    //end
   // initial begin
     //   $fs_default_status("OK");
    //end
    
    // Check for latent errors
    int regfile_cmp_core0, regfile_cmp_core1, fp_regfile_cmp_core0, fp_regfile_cmp_core1, scoreboard_cmp_core0, scoreboard_cmp_core1;
    logic [NUM_WORDS-1:0][CVA6Cfg.FLen-1:0] fp_reg_mem_core0;
    logic [NUM_WORDS-1:0][CVA6Cfg.FLen-1:0] fp_reg_mem_core1;
    logic [NUM_WORDS-1:0][CVA6Cfg.XLEN-1:0] reg_mem_core0;
    logic [NUM_WORDS-1:0][CVA6Cfg.XLEN-1:0] reg_mem_core1;

    localparam ICACHE_OFFSET_WIDTH = $clog2(CVA6Cfg.ICACHE_LINE_WIDTH / 8);
    localparam ICACHE_NUM_WORDS = 2 ** (CVA6Cfg.ICACHE_INDEX_WIDTH - ICACHE_OFFSET_WIDTH);
    localparam ICACHE_TAG_WIDTH = CVA6Cfg.ICACHE_TAG_WIDTH + 1;
    localparam ICACHE_DATA_WIDTH = CVA6Cfg.ICACHE_LINE_WIDTH;

    // Check for Instruction Cache  SRAM
   // int cmp_icache_data_sram0, cmp_icache_data_sram0_c1;
    int cmp_icache_data_sram0;
    logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram0 [ICACHE_NUM_WORDS-1:0];
   // logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram0_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_data_sram0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[0].data_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
  //  assign icache_data_sram0_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[0].data_sram.genblk1.data_sram.i_tc_sram.sram;


    int cmp_icache_data_sram1;
   // int cmp_icache_data_sram1_c1;
    logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram1 [ICACHE_NUM_WORDS-1:0];
   // logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram1_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_data_sram1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[1].data_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
    //assign icache_data_sram1_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[1].data_sram.genblk1.data_sram.i_tc_sram.sram;


    //int cmp_icache_data_sram2, cmp_icache_data_sram2_c1;
    int cmp_icache_data_sram2;
    logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram2 [ICACHE_NUM_WORDS-1:0];
   // logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram2_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_data_sram2 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[2].data_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
    //assign icache_data_sram2_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[2].data_sram.genblk1.data_sram.i_tc_sram.sram;


    int cmp_icache_data_sram3;
    logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram3 [ICACHE_NUM_WORDS-1:0];
   // logic [ICACHE_DATA_WIDTH -1:0] icache_data_sram3_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_data_sram3 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[3].data_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
    //assign icache_data_sram3_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[3].data_sram.genblk1.data_sram.i_tc_sram.sram;


    int cmp_icache_tag_sram0;
    logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram0 [ICACHE_NUM_WORDS-1:0];
    //logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram0_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_tag_sram0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[0].tag_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
   // assign icache_tag_sram0_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[0].tag_sram.genblk1.data_sram.i_tc_sram.sram;


    int cmp_icache_tag_sram1_c0;
    logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram1_c0 [ICACHE_NUM_WORDS-1:0];
    //logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram1_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_tag_sram1_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[1].tag_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
    //assign icache_tag_sram1_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[1].tag_sram.genblk1.data_sram.i_tc_sram.sram;


    int cmp_icache_tag_sram2_c0;
    logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram2_c0 [ICACHE_NUM_WORDS-1:0];
    //logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram2_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_tag_sram2_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[2].tag_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
   // assign icache_tag_sram2_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[2].tag_sram.genblk1.data_sram.i_tc_sram.sram;

    int cmp_icache_tag_sram3_c0;
    logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram3_c0 [ICACHE_NUM_WORDS-1:0];
    //logic [ICACHE_TAG_WIDTH -1:0] icache_tag_sram3_c1 [ICACHE_NUM_WORDS-1:0];

    assign icache_tag_sram3_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_icache_memwrap[0].i_icache_memwrap.gen_sram[3].tag_sram.genblk1.data_sram.gen_cut[0].i_tc_sram_wrapper.i_tc_sram.sram;
   // assign icache_tag_sram3_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.gen_cache_hpd.i_cache_subsystem.i_cva6_icache.gen_sram[3].tag_sram.genblk1.data_sram.i_tc_sram.sram;



//     // Check for Data Cache SRAM
//     int cmp_dcache_tag_sram0_c0;
//     logic [DCACHE_TAG_WIDTH -1:0] dcache_tag_sram0_c0 [NUM_WORDS_HPD_DIR-1:0];
//    // logic [DCACHE_TAG_WIDTH -1:0] dcache_tag_sram0_c1 [NUM_WORDS_HPD_DIR-1:0];
//

    sb_mem_t [CVA6Cfg.NR_SB_ENTRIES-1:0] scoreboard_mem_q_core0, scoreboard_mem_q_core1;

    assign scoreboard_mem_q_core0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.issue_stage_i.i_scoreboard.mem_q;
    assign scoreboard_mem_q_core1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.issue_stage_i.i_scoreboard.mem_q;

    assign fp_reg_mem_core0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.issue_stage_i.i_issue_read_operands.float_regfile_gen.gen_asic_fp_regfile.i_ariane_fp_regfile.mem;
    assign fp_reg_mem_core1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.issue_stage_i.i_issue_read_operands.float_regfile_gen.gen_asic_fp_regfile.i_ariane_fp_regfile.mem;
    assign reg_mem_core0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem;
    assign reg_mem_core1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem;

    final begin
        scoreboard_cmp_core0 = $fs_compare(scoreboard_mem_q_core0);
        scoreboard_cmp_core1 = $fs_compare(scoreboard_mem_q_core1);
        fp_regfile_cmp_core0 = $fs_compare(fp_reg_mem_core0);
        fp_regfile_cmp_core1 = $fs_compare(fp_reg_mem_core1);
        regfile_cmp_core0 = $fs_compare(reg_mem_core0);
        regfile_cmp_core1 = $fs_compare(reg_mem_core1);

        // Compare for instruction sram
        cmp_icache_data_sram0 = $fs_compare(icache_data_sram0);
       // cmp_icache_data_sram0_c1 = $fs_compare(icache_data_sram0_c1);
        cmp_icache_data_sram1 = $fs_compare(icache_data_sram1);
        //cmp_icache_data_sram1_c1 = $fs_compare(icache_data_sram1_c1);
        cmp_icache_data_sram2 = $fs_compare(icache_data_sram2);
        //cmp_icache_data_sram2_c1 = $fs_compare(icache_data_sram2_c1);
        cmp_icache_data_sram3 = $fs_compare(icache_data_sram3);
        //cmp_icache_data_sram3_c1 = $fs_compare(icache_data_sram3_c1);

        cmp_icache_tag_sram0 = $fs_compare(icache_tag_sram0);
        //cmp_icache_tag_sram0_c1 = $fs_compare(icache_tag_sram0_c1);
        cmp_icache_tag_sram1_c0 = $fs_compare(icache_tag_sram1_c0);
        //cmp_icache_tag_sram1_c1 = $fs_compare(icache_tag_sram1_c1);
        cmp_icache_tag_sram2_c0 = $fs_compare(icache_tag_sram2_c0);
        //cmp_icache_tag_sram2_c1 = $fs_compare(icache_tag_sram2_c1);
        cmp_icache_tag_sram3_c0 = $fs_compare(icache_tag_sram3_c0);
        //cmp_icache_tag_sram3_c1 = $fs_compare(icache_tag_sram3_c1);

       // cmp_dcache_data_sram0_c0 = $fs_compare(dcache_data_sram0_c0);
       // //cmp_dcache_data_sram0_c1 = $fs_compare(dcache_data_sram0_c1);
       // cmp_dcache_data_sram1_c0 = $fs_compare(dcache_data_sram1_c0);
       // cmp_dcache_data_sram1_c1 = $fs_compare(dcache_data_sram1_c1);
       // cmp_dcache_data_sram2_c0 = $fs_compare(dcache_data_sram2_c0);
       // cmp_dcache_data_sram2_c1 = $fs_compare(dcache_data_sram2_c1);
       // cmp_dcache_data_sram3_c0 = $fs_compare(dcache_data_sram3_c0);
       // cmp_dcache_data_sram3_c1 = $fs_compare(dcache_data_sram3_c1);

       // cmp_dcache_tag_sram0_c0 = $fs_compare(dcache_tag_sram0_c0);
       // // cmp_dcache_tag_sram0_c1 = $fs_compare(dcache_tag_sram0_c1);
       // cmp_dcache_tag_sram1_c0 = $fs_compare(dcache_tag_sram1_c0);
       // cmp_dcache_tag_sram1_c1 = $fs_compare(dcache_tag_sram1_c1);
       // cmp_dcache_tag_sram2_c0 = $fs_compare(dcache_tag_sram2_c0);
       // cmp_dcache_tag_sram2_c1 = $fs_compare(dcache_tag_sram2_c1);
       // cmp_dcache_tag_sram3_c0 = $fs_compare(dcache_tag_sram3_c0);
       // cmp_dcache_tag_sram3_c1 = $fs_compare(dcache_tag_sram3_c1);
       // cmp_dcache_tag_sram4_c0 = $fs_compare(dcache_tag_sram4_c0);
       // cmp_dcache_tag_sram4_c1 = $fs_compare(dcache_tag_sram4_c1);
       // cmp_dcache_tag_sram5_c0 = $fs_compare(dcache_tag_sram5_c0);
       // cmp_dcache_tag_sram5_c1 = $fs_compare(dcache_tag_sram5_c1);
       // cmp_dcache_tag_sram6_c0 = $fs_compare(dcache_tag_sram6_c0);
       // cmp_dcache_tag_sram6_c1 = $fs_compare(dcache_tag_sram6_c1);
       // cmp_dcache_tag_sram7_c0 = $fs_compare(dcache_tag_sram7_c0);
       // cmp_dcache_tag_sram7_c1 = $fs_compare(dcache_tag_sram7_c1);

        unique case ($fs_get_status())
        "FE", "FT", "FR": ; //Do nothing, already dangerous
        default: begin
            
            // Latent error in scoreboard
            if (scoreboard_cmp_core0 != 0) $fs_drop_status("LS", scoreboard_mem_q_core0);
            if (scoreboard_cmp_core1 != 0) $fs_drop_status("LS", scoreboard_mem_q_core1);
            
            // Latent error in floating point register file
            if (fp_regfile_cmp_core0 != 0) $fs_drop_status("LF", fp_reg_mem_core0);
            if (fp_regfile_cmp_core1 != 0) $fs_drop_status("LF", fp_reg_mem_core1);
               
            // Latent error in register file
            if (regfile_cmp_core0 != 0) $fs_drop_status("LR", reg_mem_core0);
            if (regfile_cmp_core1 != 0) $fs_drop_status("LR", reg_mem_core1);

            // Latent error in instruction cache
            if (cmp_icache_data_sram0 != 0) $fs_drop_status("LI", icache_data_sram0);
           // if (cmp_icache_data_sram0_c1 != 0) $fs_drop_status("LI", icache_data_sram0_c1);
            if (cmp_icache_data_sram1 != 0) $fs_drop_status("LI", icache_data_sram1);
            //if (cmp_icache_data_sram1_c1 != 0) $fs_drop_status("LI", icache_data_sram1_c1);
            if (cmp_icache_data_sram2 != 0) $fs_drop_status("LI", icache_data_sram2);
            //if (cmp_icache_data_sram2_c1 != 0) $fs_drop_status("LI", icache_data_sram2_c1);
            if (cmp_icache_data_sram3 != 0) $fs_drop_status("LI", icache_data_sram3);
            //if (cmp_icache_data_sram3_c1 != 0) $fs_drop_status("LI", icache_data_sram3_c1);
            
            if (cmp_icache_tag_sram0 != 0) $fs_drop_status("LI", icache_tag_sram0);
            //if (cmp_icache_tag_sram0_c1 != 0) $fs_drop_status("LI", icache_tag_sram0_c1);
            if (cmp_icache_tag_sram1_c0 != 0) $fs_drop_status("LI", icache_tag_sram1_c0);
            //if (cmp_icache_tag_sram1_c1 != 0) $fs_drop_status("LI", icache_tag_sram1_c1);
            if (cmp_icache_tag_sram2_c0 != 0) $fs_drop_status("LI", icache_tag_sram2_c0);
            //if (cmp_icache_tag_sram2_c1 != 0) $fs_drop_status("LI", icache_tag_sram2_c1);
            if (cmp_icache_tag_sram3_c0 != 0) $fs_drop_status("LI", icache_tag_sram3_c0);
            //if (cmp_icache_tag_sram3_c1 != 0) $fs_drop_status("LI", icache_tag_sram3_c1);

            // Latent error in data cache
            //if (cmp_dcache_data_sram0_c0 != 0) $fs_drop_status("LD", dcache_data_sram0_c0);
           //// if (cmp_dcache_data_sram0_c1 != 0) $fs_drop_status("LD", dcache_data_sram0_c1);
            //if (cmp_dcache_data_sram1_c0 != 0) $fs_drop_status("LD", dcache_data_sram1_c0);
            //if (cmp_dcache_data_sram1_c1 != 0) $fs_drop_status("LD", dcache_data_sram1_c1);
            //if (cmp_dcache_data_sram2_c0 != 0) $fs_drop_status("LD", dcache_data_sram2_c0);
            //if (cmp_dcache_data_sram2_c1 != 0) $fs_drop_status("LD", dcache_data_sram2_c1);
            //if (cmp_dcache_data_sram3_c0 != 0) $fs_drop_status("LD", dcache_data_sram3_c0);
            //if (cmp_dcache_data_sram3_c1 != 0) $fs_drop_status("LD", dcache_data_sram3_c1);
            //if (cmp_dcache_tag_sram0_c0 != 0) $fs_drop_status("LD", dcache_tag_sram0_c0);
          ////  if (cmp_dcache_tag_sram0_c1 != 0) $fs_drop_status("LD", dcache_tag_sram0_c1);
            //if (cmp_dcache_tag_sram1_c0 != 0) $fs_drop_status("LD", dcache_tag_sram1_c0);
            //if (cmp_dcache_tag_sram1_c1 != 0) $fs_drop_status("LD", dcache_tag_sram1_c1);
            //if (cmp_dcache_tag_sram2_c0 != 0) $fs_drop_status("LD", dcache_tag_sram2_c0);
            //if (cmp_dcache_tag_sram2_c1 != 0) $fs_drop_status("LD", dcache_tag_sram2_c1);
            //if (cmp_dcache_tag_sram3_c0 != 0) $fs_drop_status("LD", dcache_tag_sram3_c0);
            //if (cmp_dcache_tag_sram3_c1 != 0) $fs_drop_status("LD", dcache_tag_sram3_c1);
            //if (cmp_dcache_tag_sram4_c0 != 0) $fs_drop_status("LD", dcache_tag_sram4_c0);
            //if (cmp_dcache_tag_sram4_c1 != 0) $fs_drop_status("LD", dcache_tag_sram4_c1);
            //if (cmp_dcache_tag_sram5_c0 != 0) $fs_drop_status("LD", dcache_tag_sram5_c0);
            //if (cmp_dcache_tag_sram5_c1 != 0) $fs_drop_status("LD", dcache_tag_sram5_c1);
            //if (cmp_dcache_tag_sram6_c0 != 0) $fs_drop_status("LD", dcache_tag_sram6_c0);
            //if (cmp_dcache_tag_sram6_c1 != 0) $fs_drop_status("LD", dcache_tag_sram6_c1);
            //if (cmp_dcache_tag_sram7_c0 != 0) $fs_drop_status("LD", dcache_tag_sram7_c0);
            //if (cmp_dcache_tag_sram7_c1 != 0) $fs_drop_status("LD", dcache_tag_sram7_c1);
        end
        endcase
    end
    

    // CSR regfile latent error
    int cmp_priv_lvl_c0, cmp_priv_lvl_c1;
    riscv::priv_lvl_t priv_lvl_q_c0, priv_lvl_q_c1;
    assign priv_lvl_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.priv_lvl_q;
    assign priv_lvl_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.priv_lvl_q;
    // floating-point registers
    int cmp_fcsr_c0, cmp_fcsr_c1;
    riscv::fcsr_t fcsr_q_c0, fcsr_q_c1;
    assign fcsr_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.fcsr_q;
    assign fcsr_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.fcsr_q;

    int cmp_jvt_c0, cmp_jvt_c1;
    jvt_t jvt_q_c0, jvt_q_c1;
    assign jvt_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.jvt_q;
    assign jvt_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.jvt_q;

    int cmp_debug_mode_c0, cmp_debug_mode_c1;
    logic debug_mode_q_c0, debug_mode_q_c1;

    assign debug_mode_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.debug_mode_q;
    assign debug_mode_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.debug_mode_q;

    int cmp_dcsr_c0, cmp_dcsr_c1;
    riscv::dcsr_t dcsr_q_c0, dcsr_q_c1;
    assign dcsr_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.dcsr_q;
    assign dcsr_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.dcsr_q;

    int cmp_dpc_c0, cmp_dpc_c1;
    logic [CVA6Cfg.XLEN-1:0] dpc_q_c0, dpc_q_c1;
    assign dpc_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.dpc_q;
    assign dpc_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.dpc_q;

    int cmp_dscratch0_c0, cmp_dscratch0_c1;
    logic [CVA6Cfg.XLEN-1:0] dscratch0_q_c0, dscratch0_q_c1;
    assign dscratch0_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.dscratch0_q;
    assign dscratch0_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.dscratch0_q;

    int cmp_dscratch1_c0, cmp_dscratch1_c1;
    logic [CVA6Cfg.XLEN-1:0] dscratch1_q_c0, dscratch1_q_c1;
    assign dscratch1_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.dscratch1_q;
    assign dscratch1_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.dscratch1_q;

    int cmp_mstatus_c0, cmp_mstatus_c1;
    riscv::mstatus_rv_t mstatus_q_c0, mstatus_q_c1;
    assign mstatus_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mstatus_q;
    assign mstatus_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mstatus_q;

    int cmp_mtvec_rst_load_c0, cmp_mtvec_rst_load_c1;
    logic mtvec_rst_load_q_c0, mtvec_rst_load_q_c1;
    assign mtvec_rst_load_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mtvec_rst_load_q;
    assign mtvec_rst_load_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mtvec_rst_load_q;
    
    int cmp_mtvec_c0, cmp_mtvec_c1;
    logic [CVA6Cfg.XLEN-1:0] mtvec_q_c0, mtvec_q_c1;
    assign mtvec_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mtvec_q;
    assign mtvec_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mtvec_q;

    int cmp_mip_c0, cmp_mip_c1;
    logic [CVA6Cfg.XLEN-1:0] mip_q_c0, mip_q_c1;
    assign mip_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mip_q;
    assign mip_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mip_q;

    int cmp_mie_c0, cmp_mie_c1;
    logic [CVA6Cfg.XLEN-1:0] mie_q_c0, mie_q_c1;
    assign mie_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mie_q;
    assign mie_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mie_q;

    //int cmp_mintstatus_c0, cmp_mintstatus_c1;
    //riscv::intstatus_rv_t mintstatus_q_c0, mintstatus_q_c1;
    //assign mintstatus_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mintstatus_q;
    //assign mintstatus_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mintstatus_q;
    

    //int cmp_mintthresh_c0, cmp_mintthresh_c1;
    //riscv::intthresh_rv_t mintthresh_q_c0, mintthresh_q_c1;
    //assign mintthresh_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mintthresh_q;
    //assign mintthresh_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mintthresh_q;

    int cmp_mepc_c0, cmp_mepc_c1;
    logic [CVA6Cfg.XLEN-1:0] mepc_q_c0, mepc_q_c1;
    assign mepc_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mepc_q;
    assign mepc_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mepc_q;

    int cmp_mcause_c0, cmp_mcause_c1;
    logic [CVA6Cfg.XLEN-1:0] mcause_q_c0, mcause_q_c1;
    assign mcause_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mcause_q;
    assign mcause_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mcause_q;

    int cmp_mcounteren_c0, cmp_mcounteren_c1;
    logic [CVA6Cfg.XLEN-1:0] mcounteren_q_c0, mcounteren_q_c1;
    assign mcounteren_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mcounteren_q;
    assign mcounteren_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mcounteren_q;

    //int cmp_mtvt_c0, cmp_mtvt_c1;
    //logic [CVA6Cfg.XLEN-1:0] mtvt_q_c0, mtvt_q_c1;
    //assign mtvt_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mtvt_q;
    //assign mtvt_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mtvt_q;

    int cmp_mscratch_c0, cmp_mscratch_c1;
    logic [CVA6Cfg.XLEN-1:0] mscratch_q_c0, mscratch_q_c1;
    assign mscratch_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mscratch_q;
    assign mscratch_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mscratch_q;

    int cmp_mtval_c0, cmp_mtval_c1;
    logic [CVA6Cfg.XLEN-1:0] mtval_q_c0, mtval_q_c1;
    assign mtval_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mtval_q;
    assign mtval_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mtval_q;

    int cmp_fiom_c0, cmp_fiom_c1;
    logic fiom_q_c0, fiom_q_c1;
    assign fiom_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.fiom_q;
    assign fiom_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.fiom_q;

    int cmp_dcache_c0, cmp_dcache_c1;
    logic [CVA6Cfg.XLEN-1:0] dcache_q_c0, dcache_q_c1;
    assign dcache_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.dcache_q;
    assign dcache_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.dcache_q;

    int cmp_icache_c0, cmp_icache_c1;
    logic [CVA6Cfg.XLEN-1:0] icache_q_c0, icache_q_c1;
    assign icache_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.icache_q;
    assign icache_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.icache_q;

    int cmp_mcountinhibit_c0, cmp_mcountinhibit_c1; 
    logic [MHPMCounterNum+3-1:0] mcountinhibit_q_c0, mcountinhibit_q_c1;
    assign mcountinhibit_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mcountinhibit_q;
    assign mcountinhibit_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mcountinhibit_q;

    int cmp_acc_cons_c0, cmp_acc_cons_c1;
    logic [CVA6Cfg.XLEN-1:0] acc_cons_q_c0, acc_cons_q_c1;
    assign acc_cons_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.acc_cons_q;
    assign acc_cons_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.acc_cons_q;

   // int cmp_fence_t_pad_c0, cmp_fence_t_pad_c1;  
   // logic [CVA6Cfg.XLEN-1:0] fence_t_pad_q_c0, fence_t_pad_q_c1; 
   // assign fence_t_pad_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.fence_t_pad_q;
   // assign fence_t_pad_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.fence_t_pad_q;

   // int cmp_fence_t_sel_c0, cmp_fence_t_sel_c1;
   // logic [CVA6Cfg.XLEN-1:0] fence_t_sel_q_c0, fence_t_sel_q_c1;
   // assign fence_t_sel_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.fence_t_sel_q;
   // assign fence_t_sel_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.fence_t_sel_q;

   // int cmp_fence_t_ceil_c0, cmp_fence_t_ceil_c1; 
   // logic [CVA6Cfg.XLEN-1:0] fence_t_ceil_q_c0, fence_t_ceil_q_c1;
   // assign fence_t_ceil_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.fence_t_ceil_q;
   // assign fence_t_ceil_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.fence_t_ceil_q;

    // supervisor mode registers
    int cmp_medeleg_c0, cmp_medeleg_c1;
    logic [CVA6Cfg.XLEN-1:0] medeleg_q_c0, medeleg_q_c1;
    assign medeleg_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.medeleg_q;
    assign medeleg_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.medeleg_q;

    int cmp_mideleg_c0, cmp_mideleg_c1;   
    logic [CVA6Cfg.XLEN-1:0] mideleg_q_c0, mideleg_q_c1;
    assign mideleg_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mideleg_q;
    assign mideleg_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mideleg_q;

    int cmp_sepc_c0, cmp_sepc_c1; 
    logic [CVA6Cfg.XLEN-1:0] sepc_q_c0, sepc_q_c1;
    assign sepc_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.sepc_q;
    assign sepc_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.sepc_q;

    int cmp_scause_c0, cmp_scause_c1;   
    logic [CVA6Cfg.XLEN-1:0] scause_q_c0, scause_q_c1;
    assign scause_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.scause_q;
    assign scause_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.scause_q;

    int cmp_stvec_c0, cmp_stvec_c1;
    logic [CVA6Cfg.XLEN-1:0] stvec_q_c0, stvec_q_c1;
    assign stvec_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.stvec_q;
    assign stvec_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.stvec_q;

    int cmp_scounteren_c0, cmp_scounteren_c1; 
    logic [CVA6Cfg.XLEN-1:0] scounteren_q_c0, scounteren_q_c1;
    assign scounteren_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.scounteren_q;
    assign scounteren_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.scounteren_q;

    int cmp_sscratch_c0, cmp_sscratch_c1;   
    logic [CVA6Cfg.XLEN-1:0] sscratch_q_c0, sscratch_q_c1;
    assign sscratch_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.sscratch_q;
    assign sscratch_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.sscratch_q;

    int cmp_stval_c0, cmp_stval_c1;
    logic [CVA6Cfg.XLEN-1:0] stval_q_c0, stval_q_c1;
    assign stval_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.stval_q;
    assign stval_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.stval_q;

    int cmp_satp_c0, cmp_satp_c1;    
    satp_t satp_q_c0, satp_q_c1;
    assign satp_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.satp_q;
    assign satp_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.satp_q;

    //int cmp_stvt_c0, cmp_stvt_c1;   
   // logic [CVA6Cfg.XLEN-1:0] stvt_q_c0, stvt_q_c1;
    //assign stvt_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.stvt_q;
    //assign stvt_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.stvt_q;

   // int cmp_sintthresh_c0, cmp_sintthresh_c1;
   // riscv::intthresh_rv_t sintthresh_q_c0, sintthresh_q_c1;
   // assign sintthresh_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.sintthresh_q;
   // assign sintthresh_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.sintthresh_q;

    int cmp_v_c0, cmp_v_c1;
    logic v_q_c1, v_q_c0;
    assign v_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.v_q;
    assign v_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.v_q;

    int cmp_mtval2_c0, cmp_mtval2_c1; 
    logic [CVA6Cfg.XLEN-1:0] mtval2_q_c0, mtval2_q_c1;
    assign mtval2_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mtval2_q;
    assign mtval2_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mtval2_q;

    int cmp_mtinst_c0, cmp_mtinst_c1; 
    logic [CVA6Cfg.XLEN-1:0] mtinst_q_c0, mtinst_q_c1;
    assign mtinst_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.mtinst_q;
    assign mtinst_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.mtinst_q;

   // int cmp_hstatus_c0, cmp_hstatus_c1;
   // riscv::hstatus_rv_t hstatus_q_c0, hstatus_q_c1;
   // assign hstatus_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.hstatus_q;
   // assign hstatus_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.hstatus_q;

    int cmp_hedeleg_c0, cmp_hedeleg_c1;   
    logic [CVA6Cfg.XLEN-1:0] hedeleg_q_c0, hedeleg_q_c1;
    assign hedeleg_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.hedeleg_q;
    assign hedeleg_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.hedeleg_q;

    int cmp_hideleg_c0, cmp_hideleg_c1;  
    logic [CVA6Cfg.XLEN-1:0] hideleg_q_c0, hideleg_q_c1; 
    assign hideleg_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.hideleg_q;
    assign hideleg_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.hideleg_q;

    int cmp_hgeie_c0, cmp_hgeie_c1;   
    logic [CVA6Cfg.XLEN-1:0] hgeie_q_c0, hgeie_q_c1;   
    assign hgeie_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.hgeie_q;
    assign hgeie_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.hgeie_q;

    int cmp_hgatp_c0, cmp_hgatp_c1;   
    hgatp_t hgatp_q_c0, hgatp_q_c1;
    assign hgatp_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.hgatp_q;
    assign hgatp_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.hgatp_q;

    int cmp_hcounteren_c0, cmp_hcounteren_c1;   
    logic [CVA6Cfg.XLEN-1:0] hcounteren_q_c0, hcounteren_q_c1;
    assign hcounteren_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.hcounteren_q;
    assign hcounteren_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.hcounteren_q;

    int cmp_htval_c0, cmp_htval_c1;  
    logic [CVA6Cfg.XLEN-1:0] htval_q_c0, htval_q_c1;  
    assign htval_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.htval_q;
    assign htval_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.htval_q;

    int cmp_htinst_c0, cmp_htinst_c1;    
    logic [CVA6Cfg.XLEN-1:0] htinst_q_c0, htinst_q_c1;     
    assign htinst_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.htinst_q;
    assign htinst_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.htinst_q;

  //  int cmp_vsstatus_c0, cmp_vsstatus_c1; 
   // riscv::mstatus_rv_t vsstatus_q_c0, vsstatus_q_c1;
   // assign vsstatus_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vsstatus_q;
   // assign vsstatus_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vsstatus_q;

    int cmp_vsepc_c0, cmp_vsepc_c1;
    logic [CVA6Cfg.XLEN-1:0] vsepc_q_c0, vsepc_q_c1;
    assign vsepc_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vsepc_q;
    assign vsepc_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vsepc_q;

    int cmp_vscause_c0, cmp_vscause_c1; 
    logic [CVA6Cfg.XLEN-1:0] vscause_q_c0, vscause_q_c1;     
    assign vscause_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vscause_q;
    assign vscause_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vscause_q;

    int cmp_vstvec_c0, cmp_vstvec_c1;    
    logic [CVA6Cfg.XLEN-1:0] vstvec_q_c0, vstvec_q_c1;
    assign vstvec_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vstvec_q;
    assign vstvec_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vstvec_q;

    int cmp_vsscratch_c0, cmp_vsscratch_c1;  
    logic [CVA6Cfg.XLEN-1:0] vsscratch_q_c0, vsscratch_q_c1;
    assign vsscratch_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vsscratch_q;
    assign vsscratch_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vsscratch_q;

    int cmp_vstval_c0, cmp_vstval_c1;      
    logic [CVA6Cfg.XLEN-1:0] vstval_q_c0, vstval_q_c1; 
    assign vstval_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vstval_q;
    assign vstval_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vstval_q;

    int cmp_vsatp_c0, cmp_vsatp_c1;        
    satp_t vsatp_q_c0, vsatp_q_c1;
    assign vsatp_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vsatp_q;
    assign vsatp_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vsatp_q;

    int cmp_en_ld_st_g_translation_c0, cmp_en_ld_st_g_translation_c1;
    logic en_ld_st_g_translation_q_c0, en_ld_st_g_translation_q_c1;
    assign en_ld_st_g_translation_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.en_ld_st_g_translation_q;
    assign en_ld_st_g_translation_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.en_ld_st_g_translation_q;

   // int cmp_vstvt_c0, cmp_vstvt_c1;
   // logic [CVA6Cfg.XLEN-1:0] vstvt_q_c0, vstvt_q_c1;
   // assign vstvt_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vstvt_q;
   // assign vstvt_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vstvt_q;

   // int cmp_vsintthresh_c0, cmp_vsintthresh_c1;
   // riscv::intthresh_rv_t vsintthresh_q_c0, vsintthresh_q_c1;
    //assign vsintthresh_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.vsintthresh_q;
    //assign vsintthresh_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.vsintthresh_q;

    // timer and counters
    int cmp_cycle_c0, cmp_cycle_c1;
    logic [63:0] cycle_q_c0, cycle_q_c1;
    assign cycle_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.cycle_q;
    assign cycle_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.cycle_q;

    int cmp_instret_c0, cmp_instret_c1;
    logic [63:0] instret_q_c0, instret_q_c1;
    assign instret_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.instret_q;
    assign instret_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.instret_q;

    // aux registers
    int cmp_en_ld_st_translation_c0, cmp_en_ld_st_translation_c1;
    logic en_ld_st_translation_q_c0, en_ld_st_translation_q_c1;
    assign en_ld_st_translation_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.en_ld_st_translation_q;
    assign en_ld_st_translation_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.en_ld_st_translation_q;

    // wait for interrupt
    int cmp_wfi_c0, cmp_wfi_c1;
    logic wfi_q_c0, wfi_q_c1;
    assign wfi_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.wfi_q;
    assign wfi_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.wfi_q;

    // pmp
    int cmp_pmpcfg_c0, cmp_pmpcfg_c1;
    riscv::pmpcfg_t [63:0] pmpcfg_q_c0, pmpcfg_q_c1;
    
    int cmp_pmpaddr_c0, cmp_pmpaddr_c1;
    logic [63:0][CVA6Cfg.PLEN-3:0] pmpaddr_q_c0, pmpaddr_q_c1;

    assign pmpcfg_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.pmpcfg_q;
    assign pmpcfg_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.pmpcfg_q;

    assign pmpaddr_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.csr_regfile_i.pmpaddr_q;
    assign pmpaddr_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.csr_regfile_i.pmpaddr_q;

    final begin
        cmp_priv_lvl_c0 = $fs_compare(priv_lvl_q_c0);
        cmp_priv_lvl_c1 = $fs_compare(priv_lvl_q_c1);
        // floating-point registers
        cmp_fcsr_c0 = $fs_compare(fcsr_q_c0);
        cmp_fcsr_c1 = $fs_compare(fcsr_q_c1);
        if (CVA6Cfg.RVZCMT) begin
            cmp_jvt_c0 = $fs_compare(jvt_q_c0);
            cmp_jvt_c1 = $fs_compare(jvt_q_c1);
        end
        // debug signals
        if (CVA6Cfg.DebugEn) begin
            cmp_debug_mode_c0 = $fs_compare(debug_mode_q_c0);
            cmp_dcsr_c0 = $fs_compare(dcsr_q_c0);       
            cmp_dpc_c0 = $fs_compare(dpc_q_c0);
            cmp_dscratch0_c0 = $fs_compare(dscratch0_q_c0);
            cmp_dscratch1_c0 = $fs_compare(dscratch1_q_c0); 
            
            cmp_debug_mode_c1 = $fs_compare(debug_mode_q_c1);
            cmp_dcsr_c1 = $fs_compare(dcsr_q_c1);       
            cmp_dpc_c1 = $fs_compare(dpc_q_c1);
            cmp_dscratch0_c1 = $fs_compare(dscratch0_q_c1);
            cmp_dscratch1_c1 = $fs_compare(dscratch1_q_c1); 
        end
        // machine mode registers
        cmp_mstatus_c0 = $fs_compare(mstatus_q_c0); 
        cmp_mstatus_c1 = $fs_compare(mstatus_q_c1);   
        // set to boot address + direct mode + 4 byte offset which is the initial trap
        cmp_mtvec_rst_load_c0 = $fs_compare(mtvec_rst_load_q_c0);
        cmp_mtvec_c0 = $fs_compare(mtvec_q_c0);          
        cmp_mip_c0 = $fs_compare(mip_q_c0);            
        cmp_mie_c0 = $fs_compare(mie_q_c0);            
        //cmp_mintstatus_c0 = $fs_compare(mintstatus_q_c0);     
       // cmp_mintthresh_c0 = $fs_compare(mintthresh_q_c0);    
        cmp_mepc_c0 = $fs_compare(mepc_q_c0);           
        cmp_mcause_c0 = $fs_compare(mcause_q_c0);         
        cmp_mcounteren_c0 = $fs_compare(mcounteren_q_c0);     
       // cmp_mtvt_c0 = $fs_compare(mtvt_q_c0);           
        cmp_mscratch_c0 = $fs_compare(mscratch_q_c0);    

        cmp_mtvec_rst_load_c1 = $fs_compare(mtvec_rst_load_q_c1);
        cmp_mtvec_c1 = $fs_compare(mtvec_q_c1);          
        cmp_mip_c1 = $fs_compare(mip_q_c1);            
        cmp_mie_c1 = $fs_compare(mie_q_c1);            
        //cmp_mintstatus_c1 = $fs_compare(mintstatus_q_c1);     
        //cmp_mintthresh_c1 = $fs_compare(mintthresh_q_c1);    
        cmp_mepc_c1 = $fs_compare(mepc_q_c1);           
        cmp_mcause_c1 = $fs_compare(mcause_q_c1);         
        cmp_mcounteren_c1 = $fs_compare(mcounteren_q_c1);     
       // cmp_mtvt_c1 = $fs_compare(mtvt_q_c1);           
        cmp_mscratch_c1 = $fs_compare(mscratch_q_c1);        
        if (CVA6Cfg.TvalEn) begin
            cmp_mtval_c0 = $fs_compare(mtval_q_c0);
            cmp_mtval_c1 = $fs_compare(mtval_q_c1);
        end

        cmp_fiom_c0 = $fs_compare(fiom_q_c0);          
        cmp_dcache_c0 = $fs_compare(dcache_q_c0);        
        cmp_icache_c0 = $fs_compare(icache_q_c0);        
        cmp_mcountinhibit_c0 = $fs_compare(mcountinhibit_q_c0); 
        cmp_acc_cons_c0 = $fs_compare(acc_cons_q_c0);    
       // cmp_fence_t_pad_c0 = $fs_compare(fence_t_pad_q_c0);   
       // cmp_fence_t_sel_c0 = $fs_compare(fence_t_sel_q_c0);   
       // cmp_fence_t_ceil_c0 = $fs_compare(fence_t_ceil_q_c0); 

        cmp_fiom_c1 = $fs_compare(fiom_q_c1);          
        cmp_dcache_c1 = $fs_compare(dcache_q_c1);        
        cmp_icache_c1 = $fs_compare(icache_q_c1);        
        cmp_mcountinhibit_c1 = $fs_compare(mcountinhibit_q_c1); 
        cmp_acc_cons_c1 = $fs_compare(acc_cons_q_c1);    
        //cmp_fence_t_pad_c1 = $fs_compare(fence_t_pad_q_c1);   
        //cmp_fence_t_sel_c1 = $fs_compare(fence_t_sel_q_c1);   
        //cmp_fence_t_ceil_c1 = $fs_compare(fence_t_ceil_q_c1);  
        //// supervisor mode registers
        if (CVA6Cfg.RVS) begin
            cmp_medeleg_c0 = $fs_compare(medeleg_q_c0);    
            cmp_mideleg_c0 = $fs_compare(mideleg_q_c0);    
            cmp_sepc_c0 = $fs_compare(sepc_q_c0);       
            cmp_scause_c0 = $fs_compare(scause_q_c0);     
            cmp_stvec_c0 = $fs_compare(stvec_q_c0);      
            cmp_scounteren_c0 = $fs_compare(scounteren_q_c0); 
            cmp_sscratch_c0 = $fs_compare(sscratch_q_c0);   
            cmp_stval_c0 = $fs_compare(stval_q_c0);      
            cmp_satp_c0 = $fs_compare(satp_q_c0);     

            cmp_medeleg_c1 = $fs_compare(medeleg_q_c1);    
            cmp_mideleg_c1 = $fs_compare(mideleg_q_c1);    
            cmp_sepc_c1 = $fs_compare(sepc_q_c1);       
            cmp_scause_c1 = $fs_compare(scause_q_c1);     
            cmp_stvec_c1 = $fs_compare(stvec_q_c1);      
            cmp_scounteren_c1 = $fs_compare(scounteren_q_c1); 
            cmp_sscratch_c1 = $fs_compare(sscratch_q_c1);   
            cmp_stval_c1 = $fs_compare(stval_q_c1);      
            cmp_satp_c1 = $fs_compare(satp_q_c1);  
            //if (CVA6Cfg.RVSCLIC) begin
            //   cmp_stvt_c0 = $fs_compare(stvt_q_c0);
            //   // cmp_sintthresh_c0 = $fs_compare(sintthresh_q_c0);
//
            //    cmp_stvt_c1 = $fs_compare(stvt_q_c1);
            //    //cmp_sintthresh_c1 = $fs_compare(sintthresh_q_c1);
            //end
        end

        if (CVA6Cfg.RVH) begin
            cmp_v_c0 = $fs_compare(v_q_c0);                      
            cmp_mtval2_c0 = $fs_compare(mtval2_q_c0);           
            cmp_mtinst_c0 = $fs_compare(mtinst_q_c0);            
            //cmp_hstatus_c0 = $fs_compare(hstatus_q_c0);          
            cmp_hedeleg_c0 = $fs_compare(hedeleg_q_c0);          
            cmp_hideleg_c0 = $fs_compare(hideleg_q_c0);          
            cmp_hgeie_c0 = $fs_compare(hgeie_q_c0);             
            cmp_hgatp_c0 = $fs_compare(hgatp_q_c0);              
            cmp_hcounteren_c0 = $fs_compare(hcounteren_q_c0);    
            cmp_htval_c0 = $fs_compare(htval_q_c0);              
            cmp_htinst_c0 = $fs_compare(htinst_q_c0);

            cmp_v_c1 = $fs_compare(v_q_c1);                      
            cmp_mtval2_c1 = $fs_compare(mtval2_q_c1);           
            cmp_mtinst_c1 = $fs_compare(mtinst_q_c1);            
            //cmp_hstatus_c1 = $fs_compare(hstatus_q_c1);          
            cmp_hedeleg_c1 = $fs_compare(hedeleg_q_c1);          
            cmp_hideleg_c1 = $fs_compare(hideleg_q_c1);          
            cmp_hgeie_c1 = $fs_compare(hgeie_q_c1);             
            cmp_hgatp_c1 = $fs_compare(hgatp_q_c1);              
            cmp_hcounteren_c1 = $fs_compare(hcounteren_q_c1);    
            cmp_htval_c1 = $fs_compare(htval_q_c1);              
            cmp_htinst_c1 = $fs_compare(htinst_q_c1);              
            // virtual supervisor mode registers
            //cmp_vsstatus_c0 = $fs_compare(vsstatus_q_c0);           
            cmp_vsepc_c0 = $fs_compare(vsepc_q_c0);                  
            cmp_vscause_c0 = $fs_compare(vscause_q_c0);              
            cmp_vstvec_c0 = $fs_compare(vstvec_q_c0);                
            cmp_vsscratch_c0 = $fs_compare(vsscratch_q_c0);          
            cmp_vstval_c0 = $fs_compare(vstval_q_c0);                
            cmp_vsatp_c0 = $fs_compare(vsatp_q_c0);                  
            cmp_en_ld_st_g_translation_c0 = $fs_compare(en_ld_st_g_translation_q_c0);

           // cmp_vsstatus_c1 = $fs_compare(vsstatus_q_c1);           
            cmp_vsepc_c1 = $fs_compare(vsepc_q_c1);                  
            cmp_vscause_c1 = $fs_compare(vscause_q_c1);              
            cmp_vstvec_c1 = $fs_compare(vstvec_q_c1);                
            cmp_vsscratch_c1 = $fs_compare(vsscratch_q_c1);          
            cmp_vstval_c1 = $fs_compare(vstval_q_c1);                
            cmp_vsatp_c1 = $fs_compare(vsatp_q_c1);                  
            cmp_en_ld_st_g_translation_c1 = $fs_compare(en_ld_st_g_translation_q_c1);
            //if (CVA6Cfg.RVXHCLIC) begin
            //    cmp_vstvt_c0 = $fs_compare(vstvt_q_c0);
            //    //cmp_vsintthresh_c0 = $fs_compare(vsintthresh_q_c0);
//
            //    cmp_vstvt_c1 = $fs_compare(vstvt_q_c1);
            //  //  cmp_vsintthresh_c1 = $fs_compare(vsintthresh_q_c1);
            //end
        end
        // timer and counters
        cmp_cycle_c0 = $fs_compare(cycle_q_c0);
        cmp_instret_c0 = $fs_compare(instret_q_c0);

        cmp_cycle_c1 = $fs_compare(cycle_q_c1);
        cmp_instret_c1 = $fs_compare(instret_q_c1);
        // aux registers
        cmp_en_ld_st_translation_c0 = $fs_compare(en_ld_st_g_translation_q_c0);
        cmp_en_ld_st_translation_c1 = $fs_compare(en_ld_st_g_translation_q_c1);
        // wait for interrupt
        cmp_wfi_c0 = $fs_compare(wfi_q_c0);
        cmp_wfi_c1 = $fs_compare(wfi_q_c1);
        // pmp
        
        cmp_pmpcfg_c0 = $fs_compare(pmpcfg_q_c0);
        cmp_pmpaddr_c0 = $fs_compare(pmpaddr_q_c0);
        
        cmp_pmpcfg_c1 = $fs_compare(pmpcfg_q_c1);
        cmp_pmpaddr_c1 = $fs_compare(pmpaddr_q_c1);

        unique case ($fs_get_status())
        "FE", "FT", "FR": ; //Do nothing, already dangerous
        default: begin
        
            if (cmp_priv_lvl_c0 != 0) $fs_drop_status("LC", priv_lvl_q_c0);
            if (cmp_priv_lvl_c1 != 0) $fs_drop_status("LC", priv_lvl_q_c1);
            // floating-point registers
            if (cmp_fcsr_c0 != 0) $fs_drop_status("LC", fcsr_q_c0);
            if (cmp_fcsr_c1 != 0) $fs_drop_status("LC", fcsr_q_c1);
            if (CVA6Cfg.RVZCMT) begin
                if (cmp_jvt_c0 != 0) $fs_drop_status("LC", jvt_q_c0);
                if (cmp_jvt_c1 != 0) $fs_drop_status("LC", jvt_q_c1);
            end
            // debug signals
            if (CVA6Cfg.DebugEn) begin
                if (cmp_debug_mode_c0 != 0) $fs_drop_status("LC", debug_mode_q_c0);
                if (cmp_dcsr_c0 != 0) $fs_drop_status("LC", dcsr_q_c0);       
                if (cmp_dpc_c0 != 0) $fs_drop_status("LC", dpc_q_c0);
                if (cmp_dscratch0_c0 != 0) $fs_drop_status("LC", dscratch0_q_c0);
                if (cmp_dscratch1_c0 != 0) $fs_drop_status("LC", dscratch1_q_c0); 

                if (cmp_debug_mode_c1 != 0) $fs_drop_status("LC", debug_mode_q_c1);
                if (cmp_dcsr_c1 != 0) $fs_drop_status("LC", dcsr_q_c1);       
                if (cmp_dpc_c1 != 0) $fs_drop_status("LC", dpc_q_c1);
                if (cmp_dscratch0_c1 != 0) $fs_drop_status("LC", dscratch0_q_c1);
                if (cmp_dscratch1_c1 != 0) $fs_drop_status("LC", dscratch1_q_c1); 
            end
            // machine mode registers
            if (cmp_mstatus_c0 != 0) $fs_drop_status("LC", mstatus_q_c0); 
            if (cmp_mstatus_c1 != 0) $fs_drop_status("LC", mstatus_q_c1);   
            // set to boot address + direct mode + 4 byte offset which is the initial trap
            if (cmp_mtvec_rst_load_c0 != 0) $fs_drop_status("LC", mtvec_rst_load_q_c0);
            if (cmp_mtvec_c0 != 0) $fs_drop_status("LC", mtvec_q_c0);          
            if (cmp_mip_c0 != 0) $fs_drop_status("LC", mip_q_c0);            
            if (cmp_mie_c0 != 0) $fs_drop_status("LC", mie_q_c0);            
           // if (cmp_mintstatus_c0 != 0) $fs_drop_status("LC", mintstatus_q_c0);     
           // if (cmp_mintthresh_c0 != 0) $fs_drop_status("LC", mintthresh_q_c0);    
            if (cmp_mepc_c0 != 0) $fs_drop_status("LC", mepc_q_c0);           
            if (cmp_mcause_c0 != 0) $fs_drop_status("LC", mcause_q_c0);         
            if (cmp_mcounteren_c0 != 0) $fs_drop_status("LC", mcounteren_q_c0);     
            //if (cmp_mtvt_c0 != 0) $fs_drop_status("LC", mtvt_q_c0);           
            if (cmp_mscratch_c0 != 0) $fs_drop_status("LC", mscratch_q_c0);    

            if (cmp_mtvec_rst_load_c1 != 0) $fs_drop_status("LC", mtvec_rst_load_q_c1);
            if (cmp_mtvec_c1 != 0) $fs_drop_status("LC", mtvec_q_c1);          
            if (cmp_mip_c1 != 0) $fs_drop_status("LC", mip_q_c1);            
            if (cmp_mie_c1 != 0) $fs_drop_status("LC", mie_q_c1);            
           // if (cmp_mintstatus_c1 != 0) $fs_drop_status("LC", mintstatus_q_c1);     
           // if (cmp_mintthresh_c1 != 0) $fs_drop_status("LC", mintthresh_q_c1);    
            if (cmp_mepc_c1 != 0) $fs_drop_status("LC", mepc_q_c1);           
            if (cmp_mcause_c1 != 0) $fs_drop_status("LC", mcause_q_c1);         
            if (cmp_mcounteren_c1 != 0) $fs_drop_status("LC", mcounteren_q_c1);     
            //if (cmp_mtvt_c1 != 0) $fs_drop_status("LC", mtvt_q_c1);           
            if (cmp_mscratch_c1 != 0) $fs_drop_status("LC", mscratch_q_c1);        
            if (CVA6Cfg.TvalEn) begin
                if (cmp_mtval_c0 != 0) $fs_drop_status("LC", mtval_q_c0);
                if (cmp_mtval_c1 != 0) $fs_drop_status("LC", mtval_q_c1);
            end

            if (cmp_fiom_c0 != 0) $fs_drop_status("LC", fiom_q_c0);          
            if (cmp_dcache_c0 != 0) $fs_drop_status("LC", dcache_q_c0);        
            if (cmp_icache_c0 != 0) $fs_drop_status("LC", icache_q_c0);        
            if (cmp_mcountinhibit_c0 != 0) $fs_drop_status("LC", mcountinhibit_q_c0); 
            if (cmp_acc_cons_c0 != 0) $fs_drop_status("LC", acc_cons_q_c0);    
           // if (cmp_fence_t_pad_c0 != 0) $fs_drop_status("LC", fence_t_pad_q_c0);   
           // if (cmp_fence_t_sel_c0 != 0) $fs_drop_status("LC", fence_t_sel_q_c0);   
           // if (cmp_fence_t_ceil_c0 != 0) $fs_drop_status("LC", fence_t_ceil_q_c0); 

            if (cmp_fiom_c1 != 0) $fs_drop_status("LC",fiom_q_c1);          
            if (cmp_dcache_c1 != 0) $fs_drop_status("LC",dcache_q_c1);        
            if (cmp_icache_c1 != 0) $fs_drop_status("LC",icache_q_c1);        
            if (cmp_mcountinhibit_c1 != 0) $fs_drop_status("LC",mcountinhibit_q_c1); 
            if (cmp_acc_cons_c1 != 0) $fs_drop_status("LC",acc_cons_q_c1);    
            //if (cmp_fence_t_pad_c1 != 0) $fs_drop_status("LC",fence_t_pad_q_c1);   
            //if (cmp_fence_t_sel_c1 != 0) $fs_drop_status("LC",fence_t_sel_q_c1);   
            //if (cmp_fence_t_ceil_c1 != 0) $fs_drop_status("LC",fence_t_ceil_q_c1);  
            // supervisor mode registers
            if (CVA6Cfg.RVS) begin
                if (cmp_medeleg_c0 != 0) $fs_drop_status("LC", medeleg_q_c0);    
                if (cmp_mideleg_c0 != 0) $fs_drop_status("LC", mideleg_q_c0);    
                if (cmp_sepc_c0 != 0) $fs_drop_status("LC", sepc_q_c0);       
                if (cmp_scause_c0 != 0) $fs_drop_status("LC", scause_q_c0);     
                if (cmp_stvec_c0 != 0) $fs_drop_status("LC", stvec_q_c0);      
                if (cmp_scounteren_c0 != 0) $fs_drop_status("LC", scounteren_q_c0); 
                if (cmp_sscratch_c0 != 0) $fs_drop_status("LC", sscratch_q_c0);   
                if (cmp_stval_c0 != 0) $fs_drop_status("LC", stval_q_c0);      
                if (cmp_satp_c0 != 0) $fs_drop_status("LC", satp_q_c0);     

                if (cmp_medeleg_c1 != 0) $fs_drop_status("LC", medeleg_q_c1);    
                if (cmp_mideleg_c1 != 0) $fs_drop_status("LC", mideleg_q_c1);    
                if (cmp_sepc_c1 != 0) $fs_drop_status("LC", sepc_q_c1);       
                if (cmp_scause_c1 != 0) $fs_drop_status("LC", scause_q_c1);     
                if (cmp_stvec_c1 != 0) $fs_drop_status("LC", stvec_q_c1);      
                if (cmp_scounteren_c1 != 0) $fs_drop_status("LC", scounteren_q_c1); 
                if (cmp_sscratch_c1 != 0) $fs_drop_status("LC", sscratch_q_c1);   
                if (cmp_stval_c1 != 0) $fs_drop_status("LC", stval_q_c1);      
                if (cmp_satp_c1 != 0) $fs_drop_status("LC", satp_q_c1);  
                //if (CVA6Cfg.RVSCLIC) begin
                //    if (cmp_stvt_c0 != 0) $fs_drop_status("LC", stvt_q_c0);
                //    //if (cmp_sintthresh_c0 != 0) $fs_drop_status("LC", sintthresh_q_c0);
//
                //    if (cmp_stvt_c1 != 0) $fs_drop_status("LC", stvt_q_c1);
                //    //if (cmp_sintthresh_c != 0) $fs_drop_status("LC", sintthresh_q_c1);
                //end
            end

            if (CVA6Cfg.RVH) begin
                if (cmp_v_c0 != 0) $fs_drop_status("LC", v_q_c0);                      
                if (cmp_mtval2_c0 != 0) $fs_drop_status("LC", mtval2_q_c0);           
                if (cmp_mtinst_c0 != 0) $fs_drop_status("LC", mtinst_q_c0);            
                //if (cmp_hstatus_c0 != 0) $fs_drop_status("LC", hstatus_q_c0);          
                if (cmp_hedeleg_c0 != 0) $fs_drop_status("LC", hedeleg_q_c0);          
                if (cmp_hideleg_c0 != 0) $fs_drop_status("LC", hideleg_q_c0);          
                if (cmp_hgeie_c0 != 0) $fs_drop_status("LC", hgeie_q_c0);             
                if (cmp_hgatp_c0 != 0) $fs_drop_status("LC", hgatp_q_c0);              
                if (cmp_hcounteren_c0 != 0) $fs_drop_status("LC", hcounteren_q_c0);    
                if (cmp_htval_c0 != 0) $fs_drop_status("LC", htval_q_c0);              
                if (cmp_htinst_c0 != 0) $fs_drop_status("LC", htinst_q_c0);

                if (cmp_v_c1 != 0) $fs_drop_status("LC", v_q_c1);                      
                if (cmp_mtval2_c1 != 0) $fs_drop_status("LC", mtval2_q_c1);           
                if (cmp_mtinst_c1 != 0) $fs_drop_status("LC", mtinst_q_c1);            
                //if (cmp_hstatus_c1 != 0) $fs_drop_status("LC", hstatus_q_c1);          
                if (cmp_hedeleg_c1 != 0) $fs_drop_status("LC", hedeleg_q_c1);          
                if (cmp_hideleg_c1 != 0) $fs_drop_status("LC", hideleg_q_c1);          
                if (cmp_hgeie_c1 != 0) $fs_drop_status("LC", hgeie_q_c1);             
                if (cmp_hgatp_c1 != 0) $fs_drop_status("LC", hgatp_q_c1);              
                if (cmp_hcounteren_c1 != 0) $fs_drop_status("LC", hcounteren_q_c1);    
                if (cmp_htval_c1 != 0) $fs_drop_status("LC", htval_q_c1);              
                if (cmp_htinst_c1 != 0) $fs_drop_status("LC", htinst_q_c1);              
                // virtual supervisor mode registers
                //if (cmp_vsstatus_c0 != 0) $fs_drop_status("LC", vsstatus_q_c0);           
                if (cmp_vsepc_c0 != 0) $fs_drop_status("LC", vsepc_q_c0);                  
                if (cmp_vscause_c0 != 0) $fs_drop_status("LC", vscause_q_c0);              
                if (cmp_vstvec_c0 != 0) $fs_drop_status("LC", vstvec_q_c0);                
                if (cmp_vsscratch_c0 != 0) $fs_drop_status("LC", vsscratch_q_c0);          
                if (cmp_vstval_c0 != 0) $fs_drop_status("LC", vstval_q_c0);                
                if (cmp_vsatp_c0 != 0) $fs_drop_status("LC", vsatp_q_c0);                  
                if (cmp_en_ld_st_g_translation_c0 != 0) $fs_drop_status("LC", en_ld_st_g_translation_q_c0);

                //if (cmp_vsstatus_c1 != 0) $fs_drop_status("LC", vsstatus_q_c1);           
                if (cmp_vsepc_c1 != 0) $fs_drop_status("LC", vsepc_q_c1);                  
                if (cmp_vscause_c1 != 0) $fs_drop_status("LC", vscause_q_c1);              
                if (cmp_vstvec_c1 != 0) $fs_drop_status("LC", vstvec_q_c1);                
                if (cmp_vsscratch_c1 != 0) $fs_drop_status("LC", vsscratch_q_c1);          
                if (cmp_vstval_c1 != 0) $fs_drop_status("LC", vstval_q_c1);                
                if (cmp_vsatp_c1 != 0) $fs_drop_status("LC", vsatp_q_c1);                  
                if (cmp_en_ld_st_g_translation_c1 != 0) $fs_drop_status("LC", en_ld_st_g_translation_q_c1);
                //if (CVA6Cfg.RVXHCLIC) begin
                //    if (cmp_vstvt_c0 != 0) $fs_drop_status("LC", vstvt_q_c0);
                //    //if (cmp_vsintthresh_c0 != 0) $fs_drop_status("LC", vsintthresh_q_c0);
//
                //    if (cmp_vstvt_c1 != 0) $fs_drop_status("LC", vstvt_q_c1);
                //    //if (cmp_vsintthresh_c1 != 0) $fs_drop_status("LC", vsintthresh_q_c1);
                //end
            end
            // timer and counters
            if (cmp_cycle_c0 != 0) $fs_drop_status("LC", cycle_q_c0);
            if (cmp_instret_c0 != 0) $fs_drop_status("LC", instret_q_c0);

            if (cmp_cycle_c1 != 0) $fs_drop_status("LC", cycle_q_c1);
            if (cmp_instret_c1 != 0) $fs_drop_status("LC", instret_q_c1);
            // aux registers
            if (cmp_en_ld_st_translation_c0 != 0) $fs_drop_status("LC", en_ld_st_g_translation_q_c0);
            if (cmp_en_ld_st_translation_c1 != 0) $fs_drop_status("LC", en_ld_st_g_translation_q_c1);
            // wait for interrupt
            if (cmp_wfi_c0 != 0) $fs_drop_status("LC", wfi_q_c0);
            if (cmp_wfi_c1 != 0) $fs_drop_status("LC", wfi_q_c1);
            // pmp
            if (cmp_pmpcfg_c0 != 0) $fs_drop_status("LC", pmpcfg_q_c0);
            if (cmp_pmpaddr_c0 != 0) $fs_drop_status("LC", pmpaddr_q_c0);

            if (cmp_pmpcfg_c1 != 0) $fs_drop_status("LC", pmpcfg_q_c1);
            if (cmp_pmpaddr_c1 != 0) $fs_drop_status("LC", pmpaddr_q_c1);
        end
        endcase
    end

    // Check for latent error in MMU (specificaly the TLBs)
    // Note Shared TLB is not used in this config 
    int cmp_dtlb_tags_c0, cmp_dtlb_tags_c1;
    tag_t [CVA6Cfg.DataTlbEntries-1:0] dtlb_tags_q_c0, dtlb_tags_q_c1;
    assign dtlb_tags_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_dtlb.tags_q;
    assign dtlb_tags_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_dtlb.tags_q;

    int cmp_dtlb_content_c0, cmp_dtlb_content_c1;
    content_t [CVA6Cfg.DataTlbEntries-1:0] dtlb_content_q_c0, dtlb_content_q_c1;
    assign dtlb_content_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_dtlb.content_q;
    assign dtlb_content_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_dtlb.content_q;

    int cmp_dtlb_plru_tree_c0, cmp_dtlb_plru_tree_c1;
    logic [2*(CVA6Cfg.DataTlbEntries-1)-1:0] dtlb_plru_tree_q_c0, dtlb_plru_tree_q_c1;
    assign dtlb_plru_tree_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_dtlb.plru_tree_q;
    assign dtlb_plru_tree_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_dtlb.plru_tree_q;

    int cmp_itlb_tags_c0, cmp_itlb_tags_c1;
    tag_t [CVA6Cfg.InstrTlbEntries-1:0] itlb_tags_q_c0, itlb_tags_q_c1;
    assign itlb_tags_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_itlb.tags_q;
    assign itlb_tags_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_itlb.tags_q;
    
    int cmp_itlb_content_c0, cmp_itlb_content_c1;
    content_t [CVA6Cfg.InstrTlbEntries-1:0] itlb_content_q_c0, itlb_content_q_c1;
    assign itlb_content_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_itlb.content_q;
    assign itlb_content_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_itlb.content_q;

    int cmp_itlb_plru_tree_c0, cmp_itlb_plru_tree_c1;
    logic [2*(CVA6Cfg.InstrTlbEntries-1)-1:0] itlb_plru_tree_q_c0, itlb_plru_tree_q_c1;
    assign itlb_plru_tree_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_itlb.plru_tree_q;
    assign itlb_plru_tree_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.ex_stage_i.lsu_i.gen_mmu.i_cva6_mmu.i_itlb.plru_tree_q;

    final begin
        cmp_dtlb_tags_c0      = $fs_compare(dtlb_tags_q_c0);
        cmp_dtlb_content_c0   = $fs_compare(dtlb_content_q_c0);   
        cmp_dtlb_plru_tree_c0 = $fs_compare(dtlb_plru_tree_q_c0); 

        cmp_dtlb_tags_c1      = $fs_compare(dtlb_tags_q_c1);
        cmp_dtlb_content_c1   = $fs_compare(dtlb_content_q_c1);   
        cmp_dtlb_plru_tree_c1 = $fs_compare(dtlb_plru_tree_q_c1); 

        cmp_itlb_tags_c0      = $fs_compare(itlb_tags_q_c0);
        cmp_itlb_content_c0   = $fs_compare(itlb_content_q_c0);   
        cmp_itlb_plru_tree_c0 = $fs_compare(itlb_plru_tree_q_c0); 

        cmp_itlb_tags_c1      = $fs_compare(itlb_tags_q_c1);
        cmp_itlb_content_c1   = $fs_compare(itlb_content_q_c1);   
        cmp_itlb_plru_tree_c1 = $fs_compare(itlb_plru_tree_q_c1);   

        unique case ($fs_get_status())
        "FE", "FT", "FR": ; //Do nothing, already dangerous
        default: begin
            if (cmp_dtlb_tags_c0      != 0) $fs_drop_status("LM", dtlb_tags_q_c0);
            if (cmp_dtlb_content_c0   != 0) $fs_drop_status("LM", dtlb_content_q_c0);   
            if (cmp_dtlb_plru_tree_c0 != 0) $fs_drop_status("LM", dtlb_plru_tree_q_c0); 

            if (cmp_dtlb_tags_c1      != 0) $fs_drop_status("LM", dtlb_tags_q_c1);
            if (cmp_dtlb_content_c1   != 0) $fs_drop_status("LM", dtlb_content_q_c1);   
            if (cmp_dtlb_plru_tree_c1 != 0) $fs_drop_status("LM", dtlb_plru_tree_q_c1); 

            if (cmp_itlb_tags_c0      != 0) $fs_drop_status("LM", itlb_tags_q_c0);
            if (cmp_itlb_content_c0   != 0) $fs_drop_status("LM", itlb_content_q_c0);   
            if (cmp_itlb_plru_tree_c0 != 0) $fs_drop_status("LM", itlb_plru_tree_q_c0); 

            if (cmp_itlb_tags_c1      != 0) $fs_drop_status("LM", itlb_tags_q_c1);
            if (cmp_itlb_content_c1   != 0) $fs_drop_status("LM", itlb_content_q_c1);   
            if (cmp_itlb_plru_tree_c1 != 0) $fs_drop_status("LM", itlb_plru_tree_q_c1); 
        end
        endcase
    end

    // Check for latent errors in the branch predictor
    int cmp_btb_c0, cmp_btb_c1;
    
    btb_prediction_t
        btb_q_c0[NR_ROWS_BTB-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0],
        btb_q_c1[NR_ROWS_BTB-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0];

    assign btb_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.i_frontend.btb_gen.i_btb.gen_asic_btb.btb_q;
    assign btb_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.i_frontend.btb_gen.i_btb.gen_asic_btb.btb_q;

    int cmp_bht_c0, cmp_bht_c1;

    struct packed {
        logic       valid;
        logic [1:0] saturation_counter;
    }
        bht_q_c0[NR_ROWS_BHT-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0],
        bht_q_c1[NR_ROWS_BHT-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0];

    assign bht_q_c0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.i_frontend.bht2lvl_gen.i_bht.bht_q;
    assign bht_q_c1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.i_frontend.bht2lvl_gen.i_bht.bht_q;

    final begin
        cmp_btb_c0 = $fs_compare(btb_q_c0);
        cmp_btb_c1 = $fs_compare(btb_q_c1);
    
        cmp_bht_c0 = $fs_compare(bht_q_c0);
        cmp_bht_c1 = $fs_compare(bht_q_c1);

        unique case ($fs_get_status())
        "FE", "FT", "FR": ; //Do nothing, already dangerous
        default: begin
            if (cmp_btb_c0 != 0) $fs_drop_status("LB", btb_q_c0);
            if (cmp_btb_c1 != 0) $fs_drop_status("LB", btb_q_c1);

            if (cmp_bht_c0 != 0) $fs_drop_status("LB", bht_q_c0);
            if (cmp_bht_c1 != 0) $fs_drop_status("LB", bht_q_c1);
        end
        endcase
    end     


    // Check for timeout
    int prog_termination_cmp;
    logic prog_termination;
    logic [3:0] timeout_cnt;
    assign prog_termination = tb_cheshire_soc.fix.dut.i_regs.field_storage.scratch[2].scratch.value[0];
    initial begin
        timeout_cnt = 4'd0;
        @(posedge rst_n);
        forever @(posedge clk) begin
            #(TTest);
            prog_termination_cmp = $fs_compare(prog_termination);
            if (prog_termination_cmp != 0) begin
                timeout_cnt = timeout_cnt + 1;
                // 10 CC since GM finished program, declare this as timeout
                if (timeout_cnt >= 10) $fs_drop_status("FT", prog_termination);
            end else begin
                timeout_cnt = 0; // reset counter if finished
            end
        end
    end

`ifdef REL_CORE
    // Check for DMR error detection in HMR unit
    int hmr_cmp_main, hmr_cmp_amo, hmr_cmp_dcache_flush, hmr_cmp_dcache_req, hmr_cmp_icache_req;
    logic hmr_error_main, hmr_error_amo, hmr_error_dchache_flush, hmr_error_dcache_req, hmr_error_icache_req;
    assign hmr_error_main = tb_cheshire_soc.fix.dut.i_core_wrap.i_core_relcva6.i_relcva6_hmr.dmr_failure_main;
    assign hmr_error_amo = tb_cheshire_soc.fix.dut.i_core_wrap.i_core_relcva6.i_relcva6_hmr.dmr_failure_amo_req ;
    assign hmr_error_dchache_flush = tb_cheshire_soc.fix.dut.i_core_wrap.i_core_relcva6.i_relcva6_hmr.dmr_failure_dcache_flush;
    assign hmr_error_icache_req = tb_cheshire_soc.fix.dut.i_core_wrap.i_core_relcva6.i_relcva6_hmr.dmr_failure_icache_dreq;
    assign hmr_error_dcache_req = |tb_cheshire_soc.fix.dut.i_core_wrap.i_core_relcva6.i_relcva6_hmr.dmr_failure_dcache_req;

    initial begin
        @(posedge rst_n);
        forever @(posedge clk) begin
            #(TTest);
            hmr_cmp_main = $fs_compare(hmr_error_main);
            hmr_cmp_amo = $fs_compare(hmr_error_amo);
            hmr_cmp_dcache_flush = $fs_compare(hmr_error_dchache_flush);
            hmr_cmp_icache_req = $fs_compare(hmr_error_icache_req);
            hmr_cmp_dcache_req = $fs_compare(hmr_error_dcache_req);
            if (hmr_cmp_main != 0) begin
                case ($fs_get_status())
                    "FE": $fs_drop_status("CE", hmr_error_main);
                    default: $fs_drop_status("CM", hmr_error_main);
                endcase
            end else if (hmr_cmp_amo != 0) begin
                // DMR checker detected error, hmr unit would start recorvery at this point
                case ($fs_get_status())
                    "FE": $fs_drop_status("CE", hmr_error_amo);
                    default: $fs_drop_status("CA", hmr_error_amo);
                endcase
            end else if (hmr_cmp_dcache_flush != 0) begin
                // DMR checker detected error, hmr unit would start recorvery at this point
                case ($fs_get_status())
                    "FE": $fs_drop_status("CE", hmr_error_dchache_flush);
                    default: $fs_drop_status("CF", hmr_error_dchache_flush);
                endcase                
            end else if (hmr_cmp_icache_req != 0) begin
                // DMR checker detected error, hmr unit would start recorvery at this point
                case ($fs_get_status())
                    "FE": $fs_drop_status("CE", hmr_error_icache_req);
                    default: $fs_drop_status("CI", hmr_error_icache_req);
                endcase      
            end else if (hmr_cmp_dcache_req != 0) begin
                // DMR checker detected error, hmr unit would start recorvery at this point
                case ($fs_get_status())
                    "FE": $fs_drop_status("CE", hmr_error_main);
                    default: $fs_drop_status("CD", hmr_error_dcache_req);
                endcase      
                
            end
        end
    end
`endif

    // Check for exception (FE)
    int exception_cmp1, exception_cmp2;
    logic exception_core0, exception_core1;
    
    assign exception_core0 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[0].i_cva6.commit_stage_i.exception_o.valid;
    assign exception_core1 = tb_cheshire_soc.fix.dut.gen_cva6_cores[0].i_core_cva6.gen_cva6_core[1].i_cva6.commit_stage_i.exception_o.valid;

    initial begin
        @(posedge rst_n);
        forever @(posedge clk) begin
            #(TTest);
            exception_cmp1 = $fs_compare(exception_core0);
            exception_cmp2 = $fs_compare(exception_core1);
            if (exception_cmp1 != 0) begin
                // Faulty exception in core 1
                $fs_set_status("FE", exception_core0);
            end else if (exception_cmp2 != 0) begin
                // Faulty exception in core 2
                $fs_set_status("FE", exception_core1);
            end
        end
    end

    // Check for faulty return value (FR)
    int result_cmp_core0, result_cmp_core1;
    logic [31:0] prog_result_core0, prog_result_core1;

  assign prog_result_core0 = tb_cheshire_soc.fix.dut.i_regs.field_storage.scratch[0].scratch.value[31:0];
assign prog_result_core1 = tb_cheshire_soc.fix.dut.i_regs.field_storage.scratch[1].scratch.value[31:0];

    initial begin
    @(posedge rst_n);
        forever @(posedge clk) begin
            #(TTest);
            result_cmp_core0 = $fs_compare(prog_result_core0);
            result_cmp_core1 = $fs_compare(prog_result_core1);
            if(result_cmp_core0 != 0) begin
                // Program finished incorrectly
                $fs_drop_status("FR", prog_result_core0);
            end else if (result_cmp_core1 != 0) begin
                // Latent error in scoreboard
                $fs_drop_status("FR", prog_result_core1);
            end
        end
    end
