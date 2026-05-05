module noelv_chs_axi_wrap #(
    parameter int unsigned        AddrWidth     = 48,
    parameter int unsigned        DataWidth     = 64,
    parameter int unsigned        IdWidth       = 4,
    parameter int unsigned        UserWidth     = 2,
    parameter type                axi_ar_chan_t = logic,
    parameter type                axi_aw_chan_t = logic,
    parameter type                axi_w_chan_t  = logic,
    parameter type                b_chan_t      = logic,
    parameter type                r_chan_t      = logic,
    parameter type                noc_req_t     = logic,
    parameter type                noc_resp_t    = logic,
    parameter logic        [31:0] IdcodeValue   = 32'h00000DB3,
    parameter int unsigned        Tech          = 0
) (
    input  logic            clk_i,
    input  logic            rst_ni,
    input  logic      [1:0] irq_i,
    input  logic            ipi_i,
    input  logic            time_irq_i,
    output noc_req_t        noc_req_o,
    input  noc_resp_t       noc_resp_i,
    input  logic            jtag_tck_i,
    input  logic            jtag_trst_ni,
    input  logic            jtag_tms_i,
    input  logic            jtag_tdi_i,
    output logic            jtag_tdo_o,
    output logic            jtag_tdo_oe_o
);

  noelv_chs_wrap #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .IdWidth  (IdWidth),
      .UserWidth(UserWidth),
      .manf     (IdcodeValue[11:1]),
      .part     (IdcodeValue[27:12]),
      .ver      (IdcodeValue[31:28]),
      .tech     (Tech)
  ) i_noelv_chs_wrap (
      .clk_i,
      .rst_ni,

      // interrupts
      .irq_i,
      .ipi_i,
      .time_irq_i,

      // axi request interface output
      .axi_chs_req_aw_id(noc_req_o.aw.id),
      .axi_chs_req_aw_addr(noc_req_o.aw.addr),
      .axi_chs_req_aw_len(noc_req_o.aw.len),
      .axi_chs_req_aw_size(noc_req_o.aw.size),
      .axi_chs_req_aw_burst(noc_req_o.aw.burst),
      .axi_chs_req_aw_lock(noc_req_o.aw.lock),
      .axi_chs_req_aw_cache(noc_req_o.aw.cache),
      .axi_chs_req_aw_prot(noc_req_o.aw.prot),
      .axi_chs_req_aw_qos(noc_req_o.aw.qos),
      .axi_chs_req_aw_region(noc_req_o.aw.region),
      .axi_chs_req_aw_atop(noc_req_o.aw.atop),
      .axi_chs_req_aw_user(noc_req_o.aw.user),
      .axi_chs_req_aw_valid(noc_req_o.aw_valid),
      .axi_chs_req_w_data(noc_req_o.w.data),
      .axi_chs_req_w_strb(noc_req_o.w.strb),
      .axi_chs_req_w_last(noc_req_o.w.last),
      .axi_chs_req_w_user(noc_req_o.w.user),
      .axi_chs_req_w_valid(noc_req_o.w_valid),
      .axi_chs_req_b_ready(noc_req_o.b_ready),
      .axi_chs_req_ar_id(noc_req_o.ar.id),
      .axi_chs_req_ar_addr(noc_req_o.ar.addr),
      .axi_chs_req_ar_len(noc_req_o.ar.len),
      .axi_chs_req_ar_size(noc_req_o.ar.size),
      .axi_chs_req_ar_burst(noc_req_o.ar.burst),
      .axi_chs_req_ar_lock(noc_req_o.ar.lock),
      .axi_chs_req_ar_cache(noc_req_o.ar.cache),
      .axi_chs_req_ar_prot(noc_req_o.ar.prot),
      .axi_chs_req_ar_qos(noc_req_o.ar.qos),
      .axi_chs_req_ar_region(noc_req_o.ar.region),
      .axi_chs_req_ar_user(noc_req_o.ar.user),
      .axi_chs_req_ar_valid(noc_req_o.ar_valid),
      .axi_chs_req_r_ready(noc_req_o.r_ready),

      // axi response interface input
      .axi_chs_rsp_aw_ready(noc_resp_i.aw_ready),
      .axi_chs_rsp_ar_ready(noc_resp_i.ar_ready),
      .axi_chs_rsp_w_ready(noc_resp_i.w_ready),
      .axi_chs_rsp_b_valid(noc_resp_i.b_valid),
      .axi_chs_rsp_b_id(noc_resp_i.b.id),
      .axi_chs_rsp_b_resp(noc_resp_i.b.resp),
      .axi_chs_rsp_b_user(noc_resp_i.b.user),
      .axi_chs_rsp_r_valid(noc_resp_i.r_valid),
      .axi_chs_rsp_r_id(noc_resp_i.r.id),
      .axi_chs_rsp_r_data(noc_resp_i.r.data),
      .axi_chs_rsp_r_resp(noc_resp_i.r.resp),
      .axi_chs_rsp_r_last(noc_resp_i.r.last),
      .axi_chs_rsp_r_user(noc_resp_i.r.user),

      // jtag interface
      .jtag_tck_i,
      .jtag_trst_ni,
      .jtag_tms_i,
      .jtag_tdi_i,
      .jtag_tdo_o,
      .jtag_tdo_oe_o
  );

endmodule
