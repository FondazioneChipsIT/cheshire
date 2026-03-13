library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.noelvtypes.all;
use gaisler.noelv.all;
use gaisler.noelv_cpu_cfg.all;
use gaisler.axi.all;
use gaisler.misc.all;
use gaisler.jtag.all;

entity noelv_chs_wrap is
    generic (
        AddrWidth : integer := 48;
        DataWidth : integer := 64;
        IdWidth   : integer := 4;
        UserWidth : integer := 2;
        manf      : integer range 0 to 2047 := 1753;
        part      : integer range 0 to 65535 := 50661;
        ver       : integer range 0 to 15 := 1
    );
    port (
        clk_i       : in std_ulogic;
        rst_ni      : in std_ulogic;
        irq_i       : in std_logic_vector(1 downto 0);
        ipi_i       : in std_ulogic;
        time_irq_i  : in std_ulogic;

        axi_chs_req_aw_id : out std_logic_vector(IdWidth-1 downto 0);
        axi_chs_req_aw_addr : out std_logic_vector(AddrWidth-1 downto 0);
        axi_chs_req_aw_len : out std_logic_vector(7 downto 0);
        axi_chs_req_aw_size : out std_logic_vector(2 downto 0);
        axi_chs_req_aw_burst : out std_logic_vector(1 downto 0);
        axi_chs_req_aw_lock : out std_ulogic;
        axi_chs_req_aw_cache : out std_logic_vector(3 downto 0);
        axi_chs_req_aw_prot : out std_logic_vector(2 downto 0);
        axi_chs_req_aw_qos : out std_logic_vector(3 downto 0);
        axi_chs_req_aw_region : out std_logic_vector(3 downto 0);
        axi_chs_req_aw_atop : out std_logic_vector(5 downto 0);
        axi_chs_req_aw_user : out std_logic_vector(UserWidth-1 downto 0);
        axi_chs_req_aw_valid : out std_ulogic;
        axi_chs_req_w_data : out std_logic_vector(DataWidth-1 downto 0);
        axi_chs_req_w_strb : out std_logic_vector(DataWidth/8-1 downto 0);
        axi_chs_req_w_last : out std_ulogic;
        axi_chs_req_w_user : out std_logic_vector(UserWidth-1 downto 0);
        axi_chs_req_w_valid : out std_ulogic;
        axi_chs_req_b_ready : out std_ulogic;
        axi_chs_req_ar_id : out std_logic_vector(IdWidth-1 downto 0);
        axi_chs_req_ar_addr : out std_logic_vector(AddrWidth-1 downto 0);
        axi_chs_req_ar_len : out std_logic_vector(7 downto 0);
        axi_chs_req_ar_size : out std_logic_vector(2 downto 0);
        axi_chs_req_ar_burst : out std_logic_vector(1 downto 0);
        axi_chs_req_ar_lock : out std_ulogic;
        axi_chs_req_ar_cache : out std_logic_vector(3 downto 0);
        axi_chs_req_ar_prot : out std_logic_vector(2 downto 0);
        axi_chs_req_ar_qos : out std_logic_vector(3 downto 0);
        axi_chs_req_ar_region : out std_logic_vector(3 downto 0);
        axi_chs_req_ar_user : out std_logic_vector(UserWidth-1 downto 0);
        axi_chs_req_ar_valid : out std_ulogic;
        axi_chs_req_r_ready : out std_ulogic;

        axi_chs_rsp_aw_ready : in std_ulogic;
        axi_chs_rsp_ar_ready : in std_ulogic;
        axi_chs_rsp_w_ready : in std_ulogic;
        axi_chs_rsp_b_valid : in std_ulogic;
        axi_chs_rsp_b_id : in std_logic_vector(IdWidth-1 downto 0);
        axi_chs_rsp_b_resp : in std_logic_vector(1 downto 0);
        axi_chs_rsp_b_user : in std_logic_vector(UserWidth-1 downto 0);
        axi_chs_rsp_r_valid : in std_ulogic;
        axi_chs_rsp_r_id : in std_logic_vector(IdWidth-1 downto 0);
        axi_chs_rsp_r_data : in std_logic_vector(DataWidth-1 downto 0);
        axi_chs_rsp_r_resp : in std_logic_vector(1 downto 0);
        axi_chs_rsp_r_last : in std_ulogic;
        axi_chs_rsp_r_user : in std_logic_vector(UserWidth-1 downto 0);

        jtag_tck_i : in std_ulogic;
        jtag_tms_i : in std_ulogic;
        jtag_tdi_i : in std_ulogic;
        jtag_tdo_o : out std_ulogic;
        jtag_tdo_oe_o : out std_ulogic
    );
end;

architecture rtl of noelv_chs_wrap is

    signal axi_nv_req : axi4_mosi_type;
    signal axi_nv_rsp : axi_somi_type;
    signal cpumi : ahb_mst_in_type;
    signal cpumo : ahb_mst_out_vector;
    signal cpusi : ahb_slv_in_type;
    signal cpuso : ahb_slv_out_vector;
    signal irq_nv : nv_irq_in_type;
    signal dbgi_none : nv_debug_in_type;
    signal dbgo_none : nv_debug_out_type;
    signal irqo_none : nv_irq_out_type;
    signal tpo_none : nv_full_trace_type;
    signal cnt_none : nv_counter_out_type;
    signal pwrd_none : std_ulogic;
    signal dbgo : nv_debug_out_vector(0 to 0);
    signal dbgi : nv_debug_in_vector(0 to 0);
    signal dsui : nv_dm_in_type;
    signal dsuo : nv_dm_out_type;
    signal dbgmo : ahb_mst_out_vector_type(0 to 0);
    signal dbgmi : ahb_mst_in_vector_type(0 to 0);
    signal dbgmi_none : ahb_mst_in_type;
    signal dbgmo_none : ahb_mst_out_type;
begin

    core: noelvcpu
    generic map (
        hindex   => 0,
        fabtech  => 0,
        memtech  => 0,
        --cached defines cacheability of memory areas, it overrides AMBA PnP configuration and is overridden by the PMA
        --cacheable regions in cheshire_pkg: 1000_0000 len 131072 & 2000_0000 len 2000_0000 & 8000_0000 len 8000_0000
        --cacheable regions in NOELV: 1000_0000-3FFF_FFFF & 8000_0000-FFFF_FFFF
        cached   => 16#FF0E#,
        wbmask   => 16#FFFF#, --busw width accesses are supported on all memory regions
        busw     => 64,
        physaddr => 32,
        cmemconf => 0,
        rfconf   => 0,
        fpuconf  => 0,
        tcmconf  => 0,
        mulconf  => 0,
        intcconf => 0,
        mnintid  => 0,
        snintid  => 0,
        gnintid  => 0,
        disas    => 0, --print instruction disassembly on console
        pbaddr   => 16#90000#,
        cfg      => 1024, --768 GP 1024 HP 512 MC
        scantest => 0
    )
    port map (
        clk    => clk_i,
        gclk   => clk_i,
        rstn   => rst_ni,
        ahbi   => cpumi, --ahb master interface input
        ahbo   => cpumo(0), --ahb master interface output
        ahbsi  => cpusi, --snoop port input
        ahbso  => cpuso, --only hconfig is used input
        irqi   => irq_nv,
        irqo   => irqo_none,
        dbgi   => dbgi(0),
        dbgo   => dbgo(0),
        tpo    => tpo_none,
        cnt    => cnt_none,
        pwrd   => pwrd_none
    );

    cpumo(15 downto 2) <= (others => ahbm_none);
    cpuso(15 downto 1) <= (others => ahbs_none);

    ahb_controller: ahbctrl
    generic map (
        nahbm => 2, --cpu and dm
        nahbs => 1,
        ioaddr => 16#FFF#,
        rrobin   => 1,
        split    => 1,
        debug    => 2, --print bus config on console
        fpnpen   => 0,
        shadow   => 0,
        ahbtrace => 0, --print ahb activity on console
        ahbendian => 1 --1 if little endian
    )
    port map (
        rst => rst_ni,
        clk => clk_i,
        msti => cpumi, --ahb master interface output
        msto => cpumo, --ahb master vector interface input
        slvi => cpusi, --ahb slave interface output
        slvo => cpuso --ahb slave vector interface input
    );

    ahb2axi_adapter: ahb2axi4b
    generic map (
        aximid => 8, --id of this AXI master
        always_secure => 0, 
        wbuffer_num => 4,
        rprefetch_num => 4, --prefetch accesses are converted to 4 64bit AXI accesses
        --cacheability defined in PnP is overridden by the cached generic on NOEL-V interface
        bar0 => ahb2ahb_membar(16#000#, '0', '0', 16#800#), --from 0x00000000 to 0x7FFFFFFF (2048 Mbyte), prefetchable=0, cacheable=0
        bar1 => ahb2ahb_membar(16#800#, '0', '0', 16#800#)  --from 0x80000000 to 0xFFFFFFFF (2048 Mbyte), prefetchable=0, cacheable=0
    )
    port map (
        rstn => rst_ni,
        clk => clk_i,
        ahbsi => cpusi, --ahb slave interface input
        ahbso => cpuso(0), --ahb slave interface output
        aximi => axi_nv_rsp,
        aximo => axi_nv_req
    );

    dsui.break <= '0';
    dsui.enable <= '1'; --Allows debug module to interact with the core 

    dm0 : dmnv
    generic map (
        fabtech   => 0,
        memtech   => 0,
        ncpu      => 1,
        ndbgmst   => 1,
        -- Conventional bus
        cbmidx    => 1,
        -- PnP
        dmhaddr   => 16#FE0#,
        dmhmask   => 16#FF0#,
        pnpaddrhi => 16#FFF#,
        pnpaddrlo => 16#FFF#,
        dmslvidx  => 1,
        dmmstidx  => 1,
        -- Trace
        tbits     => 30,
        --
        scantest  => 0,
        -- Pipelining
        plmdata   => 0
    )
    port map (
        clk      => clk_i,
        rstn     => rst_ni,
        --
        dbgmi    => dbgmi, --ahb interface with ahb2jtag output
        dbgmo    => dbgmo, --ahb interface with ahb2jtag input
        --
        cbmi    => cpumi, --ahb master with ahbctrl input
        cbmo    => cpumo(1), --ahb master with ahbctrl output
        cbsi    => cpusi, --ahb slave interface input
        --
        dbgi    => dbgo, --debug interface with the core
        dbgo    => dbgi, --debug interface with the core
        dsui    => dsui, --break and enable input
        dsuo    => dsuo  --not used
    );

    ahbjtag0 : ahbjtagrv
    generic map (
        tech      => 0, --use inferred TAP
        dtm_sel   => 1, --select RISCV DTM
        tapopt    => 1,
        hindex_gr => 1,
        hindex_rv => 0,
        idcode    => 9,
        manf      => manf, --cheshire manufacturer code
        part      => part, --cheshire part code
        ver       => ver,  --cheshire version code
        ainst_gr  => 2,
        dinst_gr  => 3,
        ainst_rv  => 16,
        dinst_rv  => 17
    )
    port map (
        rst       => rst_ni,
        clk       => clk_i,
        tck       => jtag_tck_i,
        tms       => jtag_tms_i,
        tdi       => jtag_tdi_i,
        tdo       => jtag_tdo_o,
        ahbi_gr   => ahbm_in_none,
        ahbo_gr   => open,
        ahbi_rv   => dbgmi(0), --ahb interface with debug module input
        ahbo_rv   => dbgmo(0), --ahb interface with debug module output
        tapo_tck  => open,
        tapo_tdi  => open,
        tapo_inst => open,
        tapo_rst  => open,
        tapo_capt => open,
        tapo_shft => open,
        tapo_upd  => open,
        tapi_tdo  => '0',
        trst      => rst_ni,
        tdoen     => jtag_tdo_oe_o,
        tckn      => open,
        tapo_tckn => open,
        tapo_ninst=> open,
        tapo_iupd => open
    );

    -- axi_mosi_type to axi_req_t mapping
    axi_chs_req_aw_id <= axi_nv_req.aw.id;
    axi_chs_req_aw_addr(31 downto 0) <= axi_nv_req.aw.addr;
    axi_chs_req_aw_addr(AddrWidth-1 downto 32) <= (others => '0');
    axi_chs_req_aw_len <= axi_nv_req.aw.len;
    axi_chs_req_aw_size <= axi_nv_req.aw.size;
    axi_chs_req_aw_burst <= axi_nv_req.aw.burst;
    axi_chs_req_aw_lock <= axi_nv_req.aw.lock;
    axi_chs_req_aw_cache <= axi_nv_req.aw.cache;
    axi_chs_req_aw_prot <= axi_nv_req.aw.prot;
    axi_chs_req_aw_qos <= axi_nv_req.aw.qos;
    axi_chs_req_aw_region <= (others => '0');
    axi_chs_req_aw_atop <= (others => '0');
    axi_chs_req_aw_user <= (others => '0');
    axi_chs_req_aw_valid <= axi_nv_req.aw.valid;
    axi_chs_req_w_data <= axi_nv_req.w.data;
    axi_chs_req_w_strb <= axi_nv_req.w.strb;
    axi_chs_req_w_last <= axi_nv_req.w.last;
    axi_chs_req_w_user <= (others => '0');
    axi_chs_req_w_valid <= axi_nv_req.w.valid;
    axi_chs_req_b_ready <= axi_nv_req.b.ready;
    axi_chs_req_ar_id <= axi_nv_req.ar.id;
    axi_chs_req_ar_addr(31 downto 0) <= axi_nv_req.ar.addr;
    axi_chs_req_ar_addr(AddrWidth-1 downto 32) <= (others => '0');
    axi_chs_req_ar_len <= axi_nv_req.ar.len;
    axi_chs_req_ar_size <= axi_nv_req.ar.size;
    axi_chs_req_ar_burst <= axi_nv_req.ar.burst;
    axi_chs_req_ar_lock <= axi_nv_req.ar.lock;
    axi_chs_req_ar_cache <= axi_nv_req.ar.cache;
    axi_chs_req_ar_prot <= axi_nv_req.ar.prot;
    axi_chs_req_ar_qos <= axi_nv_req.ar.qos;
    axi_chs_req_ar_region <= (others => '0');
    axi_chs_req_ar_user <= (others => '0');
    axi_chs_req_ar_valid <= axi_nv_req.ar.valid;
    axi_chs_req_r_ready <= axi_nv_req.r.ready;

    -- axi_somi_type to axi_rsp_t mapping
    axi_nv_rsp.aw.ready <= axi_chs_rsp_aw_ready;
    axi_nv_rsp.ar.ready <= axi_chs_rsp_ar_ready;
    axi_nv_rsp.w.ready <= axi_chs_rsp_w_ready;
    axi_nv_rsp.b.valid <= axi_chs_rsp_b_valid;
    axi_nv_rsp.b.id <= axi_chs_rsp_b_id;
    axi_nv_rsp.b.resp <= axi_chs_rsp_b_resp;
    --(others => '0') <= axi_chs_rsp_b_user;
    axi_nv_rsp.r.valid <= axi_chs_rsp_r_valid;
    axi_nv_rsp.r.id <= axi_chs_rsp_r_id;
    axi_nv_rsp.r.data <= axi_chs_rsp_r_data;
    axi_nv_rsp.r.resp <= "00" when (axi_chs_rsp_r_resp = "10") else axi_chs_rsp_r_resp; -- mask resp if SLVERR
    axi_nv_rsp.r.last <= axi_chs_rsp_r_last;
    --(others => '0') <= axi_chs_rsp_r_user;

    -- interrupts chs to nv mapping
    irq_nv.mtip <= time_irq_i;
    irq_nv.msip <= ipi_i;
    irq_nv.ssip <= '0';
    irq_nv.meip <= irq_i(0);
    irq_nv.seip <= irq_i(1);
    irq_nv.ueip <= '0';
    irq_nv.heip <= '0';
    irq_nv.hgeip <= (others => '0');
    irq_nv.stime <= (others => '0');
    irq_nv.imsic <= imsic_irq_none;
    irq_nv.aplic_meip <= '0';
    irq_nv.aplic_seip <= '0';
    irq_nv.nmirq <= (others => '0');

end;


