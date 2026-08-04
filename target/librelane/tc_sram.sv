module tc_sram_blackbox #(
    parameter int unsigned NumWords    = 32'd0,
    parameter int unsigned DataWidth   = 32'd0,
    parameter int unsigned ByteWidth   = 32'd0,
    parameter int unsigned NumPorts    = 32'd0,
    parameter int unsigned Latency     = 32'd0,
    parameter              SimInit     = "none",
    parameter bit          PrintSimCfg = 1'b0,
    parameter              ImplKey     = "none"
) ();
endmodule

module tc_sram #(
    parameter int unsigned NumWords = 32'd1024,
    parameter int unsigned DataWidth = 32'd128,
    parameter int unsigned ByteWidth = 32'd8,
    parameter int unsigned NumPorts = 32'd2,
    parameter int unsigned Latency = 32'd1,
    parameter SimInit = "none",
    parameter bit PrintSimCfg = 1'b0,
    parameter ImplKey = "none",
    parameter type impl_in_t = logic,
    parameter type impl_out_t = logic,
    parameter impl_out_t ImplOutSim = '0,
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
    parameter int unsigned BeWidth = (DataWidth + ByteWidth - 32'd1) / ByteWidth,
    parameter type addr_t = logic [AddrWidth-1:0],
    parameter type data_t = logic [DataWidth-1:0],
    parameter type be_t = logic [BeWidth-1:0]
) (
    input logic clk_i,
    input logic rst_ni,

    input logic  [NumPorts-1:0] req_i,
    input logic  [NumPorts-1:0] we_i,
    input addr_t [NumPorts-1:0] addr_i,
    input data_t [NumPorts-1:0] wdata_i,
    input be_t   [NumPorts-1:0] be_i,

    output data_t [NumPorts-1:0] rdata_o
);

  logic impl_i;
  assign impl_i = 1'b1;
  localparam P1L1 = (NumPorts == 1 & Latency == 1);

  // Assemble bit mask
  data_t [NumPorts-1:0] bm;

  for (genvar p = 0; p < NumPorts; ++p) begin : gen_bm_ports
    for (genvar b = 0; b < DataWidth; ++b) begin : gen_bm_bits
      assign bm[p][b] = be_i[p][b/ByteWidth];
    end
  end

  // We drive a static value for `impl_o` in behavioral simulation.
  // assign impl_o = ImplOutSim;

  // Generate desired cuts
  if (NumWords == 32 && DataWidth == 106 && P1L1) begin : gen_32x106xBx1
    logic [127:0] wdata128, rdata128, bm128;

    assign rdata_o  = rdata128[DataWidth-1:0];
    assign wdata128 = {{128 - DataWidth{1'b0}}, wdata_i};
    assign bm128    = {{128 - DataWidth{1'b0}}, bm};
    assign address  = {1'b0, addr_i[0][4:0]};


    RM_IHPSG13_1P_64x64_c2_bm_bist i_cut_0 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm128[63:0]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata128[63:0]),
        .A_DOUT     (rdata128[63:0]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(6'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_64x64_c2_bm_bist i_cut_1 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm128[127:64]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata128[127:64]),
        .A_DOUT     (rdata128[127:64]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(6'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 64 && DataWidth == 64 && P1L1) begin : gen_64x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;


    RM_IHPSG13_1P_64x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][5:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(6'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 64 && DataWidth == 144 && P1L1) begin : gen_64x144xBx1
    logic [191:0] wdata192, rdata192, bm192;

    assign rdata_o  = rdata192[DataWidth-1:0];
    assign wdata192 = {{192 - DataWidth{1'b0}}, wdata_i};
    assign bm192    = {{192 - DataWidth{1'b0}}, bm};
    for (genvar i = 0; i < 192/64; i++) begin : gen_64x144_cuts
        RM_IHPSG13_1P_64x64_c2_bm_bist i_cut (
            .A_CLK      (clk_i),
            .A_DLY      (impl_i),
            .A_ADDR     (addr_i[0][5:0]),
            .A_BM       (bm192[(64*(i+1))-1:64*i]),
            .A_MEN      (req_i),
            .A_WEN      (we_i),
            .A_REN      (~we_i),
            .A_DIN      (wdata192[(64*(i+1))-1:64*i]),
            .A_DOUT     (rdata192[(64*(i+1))-1:64*i]),
            .A_BIST_CLK (1'b0),
            .A_BIST_ADDR(6'd0),
            .A_BIST_DIN (64'd0),
            .A_BIST_BM  (64'd0),
            .A_BIST_MEN (1'b0),
            .A_BIST_WEN (1'b0),
            .A_BIST_REN (1'b0),
            .A_BIST_EN  (1'b0)
        );
    end

  end else if (NumWords == 64 && DataWidth == 512 && P1L1) begin : gen_64x512xBx1
    logic [512:0] wdata512, rdata512, bm512;

    assign rdata_o  = rdata512[DataWidth-1:0];
    assign wdata512 = {{512 - DataWidth{1'b0}}, wdata_i};
    assign bm512    = {{512 - DataWidth{1'b0}}, bm};
    for (genvar i = 0; i < 512/64; i++) begin : gen_64x512_cuts
        RM_IHPSG13_1P_64x64_c2_bm_bist i_cut (
            .A_CLK      (clk_i),
            .A_DLY      (impl_i),
            .A_ADDR     (addr_i[0][5:0]),
            .A_BM       (bm512[(64*(i+1))-1:64*i]),
            .A_MEN      (req_i),
            .A_WEN      (we_i),
            .A_REN      (~we_i),
            .A_DIN      (wdata512[(64*(i+1))-1:64*i]),
            .A_DOUT     (rdata512[(64*(i+1))-1:64*i]),
            .A_BIST_CLK (1'b0),
            .A_BIST_ADDR(6'd0),
            .A_BIST_DIN (64'd0),
            .A_BIST_BM  (64'd0),
            .A_BIST_MEN (1'b0),
            .A_BIST_WEN (1'b0),
            .A_BIST_REN (1'b0),
            .A_BIST_EN  (1'b0)
        );
    end

  end else if (NumWords == 128 & DataWidth == 128 & P1L1) begin : gen_128x128xBx1
    logic [127:0] wdata128, rdata128, bm128;

    assign rdata_o  = rdata128[DataWidth-1:0];
    assign wdata128 = {{128 - DataWidth{1'b0}}, wdata_i};
    assign bm128    = {{128 - DataWidth{1'b0}}, bm};
    assign address  = {1'b0, addr_i[0][6:0]};

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut_0 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm128[63:0]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata128[63:0]),
        .A_DOUT     (rdata128[63:0]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut_1 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm128[127:64]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata128[127:64]),
        .A_DOUT     (rdata128[127:64]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 128 & (DataWidth <= 64 & DataWidth > 32) & P1L1) begin : gen_128x64xBx1
    logic [63:0] wdata64, rdata64, bm64;
    logic [AddrWidth:0][NumPorts-1:0] address;

    assign rdata_o = rdata64[DataWidth-1:0];
    assign wdata64 = {{64 - DataWidth{1'b0}}, wdata_i};
    assign bm64    = {{64 - DataWidth{1'b0}}, bm};
    assign address = {1'b0, addr_i[0][6:0]};

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(8'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 128 & DataWidth == 48 & P1L1) begin : gen_128x48xBx1
    logic [47:0] wdata48, rdata48, bm48;
    logic [AddrWidth:0][NumPorts-1:0] address;

    assign rdata_o = rdata48;
    assign wdata48 = wdata_i;
    assign bm48    = bm;
    assign address = {1'b0, addr_i[0][6:0]};

    RM_IHPSG13_1P_256x48_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm48),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata48),
        .A_DOUT     (rdata48),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(6'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 128 & DataWidth == 16 & P1L1) begin : gen_128x16xBx1
    logic [15:0] wdata16, rdata16, bm16;
    logic [AddrWidth:0][NumPorts-1:0] address;

    assign rdata_o = rdata16;
    assign wdata16 = wdata_i;
    assign bm16    = bm;
    assign address = {1'b0, addr_i[0][6:0]};

    RM_IHPSG13_1P_256x16_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (address),
        .A_BM       (bm16),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata16),
        .A_DOUT     (rdata16),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(6'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 256 & DataWidth == 196 & P1L1) begin : gen_256x196xBx1
    logic [199:0] wdata200, rdata200, bm200;

    assign rdata_o  = rdata200[DataWidth-1:0];
    assign wdata200 = {{200 - DataWidth{1'b0}}, wdata_i};
    assign bm200    = {{200 - DataWidth{1'b0}}, bm};

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut_0 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm200[63:0]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata200[63:0]),
        .A_DOUT     (rdata200[63:0]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut_1 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm200[127:64]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata200[127:64]),
        .A_DOUT     (rdata200[127:64]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut_2 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm200[191:128]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata200[191:128]),
        .A_DOUT     (rdata200[191:128]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_256x8_c3_bm_bist i_cut_3 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm200[199:192]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata200[199:192]),
        .A_DOUT     (rdata200[199:192]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );


  end else if (NumWords == 256 & DataWidth == 84 & P1L1) begin : gen_256x84xBx1
    logic [95:0] wdata96, rdata96, bm96;

    assign rdata_o = rdata96[DataWidth-1:0];
    assign wdata96 = {{96 - DataWidth{1'b0}}, wdata_i};
    assign bm96    = {{96 - DataWidth{1'b0}}, bm};

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut_0 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm96[63:0]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata96[63:0]),
        .A_DOUT     (rdata96[63:0]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_256x32_c2_bm_bist i_cut_1 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm96[95:64]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata96[95:64]),
        .A_DOUT     (rdata96[95:64]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 256 & DataWidth == 64 & P1L1) begin : gen_256x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(8'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 256 & DataWidth == 48 & P1L1) begin : gen_256x48xBx1
    logic [47:0] wdata48, rdata48, bm48;

    assign rdata_o = rdata48;
    assign wdata48 = wdata_i;
    assign bm48    = bm;

    RM_IHPSG13_1P_256x48_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm48),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata48),
        .A_DOUT     (rdata48),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(8'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 256 & (DataWidth <= 32 & DataWidth > 16) & P1L1) begin : gen_256x32xBx1
    logic [31:0] wdata32, rdata32, bm32;

    assign rdata_o = rdata32[DataWidth-1:0];
    assign wdata32 = {{32 - DataWidth{1'b0}}, wdata_i};
    assign bm32    = {{32 - DataWidth{1'b0}}, bm};

    RM_IHPSG13_1P_256x32_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][7:0]),
        .A_BM       (bm32),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata32),
        .A_DOUT     (rdata32),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(8'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 512 & DataWidth == 128 & P1L1) begin : gen_512x128xBx1
    logic [127:0] wdata128, rdata128, bm128;

    assign rdata_o  = rdata128;
    assign wdata128 = wdata_i;
    assign bm128    = bm;

    RM_IHPSG13_1P_512x64_c2_bm_bist i_cut_0 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm128[63:0]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata128[63:0]),
        .A_DOUT     (rdata128[63:0]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_512x64_c2_bm_bist i_cut_1 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm128[127:64]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata128[127:64]),
        .A_DOUT     (rdata128[127:64]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 512 & (DataWidth <= 64 & DataWidth > 48) & P1L1) begin : gen_512x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64[DataWidth-1:0];
    assign wdata64 = {{64 - DataWidth{1'b0}}, wdata_i};
    assign bm64    = {{64 - DataWidth{1'b0}}, bm};

    RM_IHPSG13_1P_512x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 512 & DataWidth == 44 & P1L1) begin : gen_512x44xBx1
    logic [47:0] wdata48, rdata48, bm48;

    assign rdata_o = rdata48[DataWidth-1:0];
    assign wdata48 = {{48 - DataWidth{1'b0}}, wdata_i};
    assign bm48    = {{48 - DataWidth{1'b0}}, bm};

    RM_IHPSG13_1P_512x32_c2_bm_bist i_cut_0 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm48[31:0]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata48[31:0]),
        .A_DOUT     (rdata48[31:0]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

    RM_IHPSG13_1P_512x16_c2_bm_bist i_cut_1 (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm48[47:32]),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata48[47:32]),
        .A_DOUT     (rdata48[47:32]),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 512 && DataWidth == 32 && P1L1) begin : gen_512x32xBx1
    logic [31:0] wdata32, rdata32, bm32;

    assign rdata_o = rdata32;
    assign wdata32 = wdata_i;
    assign bm32    = bm;

    RM_IHPSG13_1P_512x32_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm32),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata32),
        .A_DOUT     (rdata32),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(8'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 512 & DataWidth == 22 & P1L1) begin : gen_512x22xBx1
    logic [31:0] wdata32, rdata32, bm32;

    assign rdata_o = rdata32[DataWidth-1:0];
    assign wdata32 = {{32 - DataWidth{1'b0}}, wdata_i};
    assign bm32    = {{32 - DataWidth{1'b0}}, bm};

    RM_IHPSG13_1P_512x32_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm32),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata32),
        .A_DOUT     (rdata32),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 512 & DataWidth == 7 & P1L1) begin : gen_512x7xBx1
    logic [7:0] wdata8, rdata8, bm8;

    assign rdata_o = rdata8[6:0];
    assign wdata8  = {1'b0, wdata_i};
    assign bm8     = {1'b0, bm};

    RM_IHPSG13_1P_512x8_c3_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][8:0]),
        .A_BM       (bm8),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata8),
        .A_DOUT     (rdata8),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 1024 & DataWidth == 64 & P1L1) begin : gen_1024x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_1024x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][9:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(10'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 2048 & DataWidth == 64 & P1L1) begin : gen_2048x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_2048x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][10:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 1024 && DataWidth == 32 && P1L1) begin : gen_1024x32xBx1
    logic [31:0] wdata32, rdata32, bm32;

    assign rdata_o = rdata32;
    assign wdata32 = wdata_i;
    assign bm32    = bm;

    RM_IHPSG13_1P_1024x32_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][9:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata32),
        .A_DOUT     (rdata32),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(9'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 2048 && DataWidth == 32 && P1L1) begin : gen_2048x32xBx1
    logic [63:0] wdata64, rdata64, bm64;
    logic sel_d, sel_q;

    // muxing neighboring bits instead of upper/lower 32bit reduces routing
    always_comb begin : gen_bit_interleaving
      for (int i = 0; i < 32; i++) begin
        // duplicate each bit
        wdata64[2*i]   = wdata_i[0][i];  // even bits (active if addr LSB is 0)
        bm64[2*i]      = bm[0][i] & ~addr_i[0][0];
        wdata64[2*i+1] = wdata_i[0][i];  // odd bits  (active if addr LSB is 1)
        bm64[2*i+1]    = bm[0][i] & addr_i[0][0];

        if (~sel_q) begin
          rdata_o[0][i] = rdata64[2*i];  // even bits
        end else begin
          rdata_o[0][i] = rdata64[2*i+1];  // odd bits
        end
      end
    end

    // LSB needed for read in next cycle
    assign sel_d = addr_i[0][0];

    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_mem_sel_q
      if (~rst_ni) sel_q <= '0;
      else if (req_i & ~we_i) sel_q <= sel_d;
    end

    RM_IHPSG13_1P_1024x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][10:1]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(10'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );

  end else if (NumWords == 2048 & DataWidth == 64 & P1L1) begin : gen_2048x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_2048x64_c2_bm_bist i_cut (
        .A_CLK      (clk_i),
        .A_DLY      (impl_i),
        .A_ADDR     (addr_i[0][10:0]),
        .A_BM       (bm64),
        .A_MEN      (req_i),
        .A_WEN      (we_i),
        .A_REN      (~we_i),
        .A_DIN      (wdata64),
        .A_DOUT     (rdata64),
        .A_BIST_CLK (1'b0),
        .A_BIST_ADDR(11'd0),
        .A_BIST_DIN (64'd0),
        .A_BIST_BM  (64'd0),
        .A_BIST_MEN (1'b0),
        .A_BIST_WEN (1'b0),
        .A_BIST_REN (1'b0),
        .A_BIST_EN  (1'b0)
    );


  end else begin : gen_blackbox

`ifndef SYNTHESIS
    initial
      $fatal(
          "No tc_sram for %m: NumWords %0d, DataWidth %0d NumPorts %0d, Latency %0d",
          NumWords,
          DataWidth,
          NumPorts
      );
`endif

    // Instantiate a non-linkable blackbox with parameters for debugging
`ifdef SYNTHESIS
    (* dont_touch = "true" *)
    tc_sram_blackbox #(
        .NumWords   (NumWords),
        .DataWidth  (DataWidth),
        .ByteWidth  (ByteWidth),
        .NumPorts   (NumPorts),
        .Latency    (Latency),
        .SimInit    (SimInit),
        .PrintSimCfg(PrintSimCfg),
        .ImplKey    (ImplKey)
    ) i_sram_blackbox ();
`endif

  end

endmodule : tc_sram

// CVA6 HPD Cache SRAM wraps
module hpdcache_sram_1rw #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2 ** ADDR_SIZE
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 cs,
    input  logic                 we,
    input  logic [ADDR_SIZE-1:0] addr,
    input  logic [DATA_SIZE-1:0] wdata,
    output logic [DATA_SIZE-1:0] rdata
);
  tc_sram #(
      .NumWords (DEPTH),
      .DataWidth(DATA_SIZE),
      .ByteWidth(DATA_SIZE),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .req_i  (cs),
      .we_i   (we),
      .addr_i (addr),
      .wdata_i(wdata),
      .be_i   (1'b1),
      .rdata_o(rdata)
  );
endmodule

/// SRAM with one R/W port and per-byte write mask
module hpdcache_sram_wbyteenable_1rw #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2 ** ADDR_SIZE
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   cs,
    input  logic                   we,
    input  logic [  ADDR_SIZE-1:0] addr,
    input  logic [  DATA_SIZE-1:0] wdata,
    input  logic [DATA_SIZE/8-1:0] wbyteenable,
    output logic [  DATA_SIZE-1:0] rdata
);
  tc_sram #(
      .NumWords (DEPTH),
      .DataWidth(DATA_SIZE),
      .ByteWidth(8),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .req_i  (cs),
      .we_i   (we),
      .addr_i (addr),
      .wdata_i(wdata),
      .be_i   (wbyteenable),
      .rdata_o(rdata)
  );
endmodule

/// SRAM with one R/W port and per-bit write mask
module hpdcache_sram_wmask_1rw #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2 ** ADDR_SIZE
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 cs,
    input  logic                 we,
    input  logic [ADDR_SIZE-1:0] addr,
    input  logic [DATA_SIZE-1:0] wdata,
    input  logic [DATA_SIZE-1:0] wmask,
    output logic [DATA_SIZE-1:0] rdata
);
  tc_sram #(
      .NumWords (DEPTH),
      .DataWidth(DATA_SIZE),
      .ByteWidth(1),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .req_i  (cs),
      .we_i   (we),
      .addr_i (addr),
      .wdata_i(wdata),
      .be_i   (wmask),
      .rdata_o(rdata)
  );
endmodule

// SARGANTANA HPDACHE SRAM wraps
module hpdcache_sram_sarg #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2 ** ADDR_SIZE
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 cs,
    input  logic                 we,
    input  logic [ADDR_SIZE-1:0] addr,
    input  logic [DATA_SIZE-1:0] wdata,
    output logic [DATA_SIZE-1:0] rdata
);
  tc_sram #(
      .NumWords (DEPTH),
      .DataWidth(DATA_SIZE),
      .ByteWidth(DATA_SIZE),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .req_i  (cs),
      .we_i   (we),
      .addr_i (addr),
      .wdata_i(wdata),
      .be_i   (1'b1),
      .rdata_o(rdata)
  );
endmodule

/// SRAM with one R/W port and per-byte write mask
module hpdcache_sram_sarg_wbyteenable_sarg #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2 ** ADDR_SIZE
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   cs,
    input  logic                   we,
    input  logic [  ADDR_SIZE-1:0] addr,
    input  logic [  DATA_SIZE-1:0] wdata,
    input  logic [DATA_SIZE/8-1:0] wbyteenable,
    output logic [  DATA_SIZE-1:0] rdata
);
  tc_sram #(
      .NumWords (DEPTH),
      .DataWidth(DATA_SIZE),
      .ByteWidth(8),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .req_i  (cs),
      .we_i   (we),
      .addr_i (addr),
      .wdata_i(wdata),
      .be_i   (wbyteenable),
      .rdata_o(rdata)
  );
endmodule

/// SRAM with one R/W port and per-bit write mask
module hpdcache_sram_sarg_wmask_sarg #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2 ** ADDR_SIZE
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 cs,
    input  logic                 we,
    input  logic [ADDR_SIZE-1:0] addr,
    input  logic [DATA_SIZE-1:0] wdata,
    input  logic [DATA_SIZE-1:0] wmask,
    output logic [DATA_SIZE-1:0] rdata
);
  tc_sram #(
      .NumWords (DEPTH),
      .DataWidth(DATA_SIZE),
      .ByteWidth(1),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .req_i  (cs),
      .we_i   (we),
      .addr_i (addr),
      .wdata_i(wdata),
      .be_i   (wmask),
      .rdata_o(rdata)
  );
endmodule

module sargantana_icache_way #(
    parameter int unsigned SET_WIDHT  = 32 * 8,
    parameter int unsigned ADDR_WIDHT = 6
) (
    input  logic                  clk_i,
    input  logic                  rstn_i,
    input  logic                  req_i,
    input  logic                  we_i,
    input  logic [ SET_WIDHT-1:0] data_i,
    input  logic [ADDR_WIDHT-1:0] addr_i,
    output logic [ SET_WIDHT-1:0] data_o
);
  tc_sram #(
      .NumWords (2 ** ADDR_WIDHT),
      .DataWidth(SET_WIDHT),
      .ByteWidth(1),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk_i),
      .rst_ni (rstn_i),
      .req_i  (req_i),
      .we_i   (we_i),
      .addr_i (addr_i),
      .wdata_i(data_i),
      .be_i   ({SET_WIDHT{we_i}}),
      .rdata_o(data_o)
  );
endmodule

module sargantana_itag_memory_sram #(
    parameter int unsigned ICACHE_N_WAY   = 4,
    parameter int unsigned TAG_DEPTH      = 64,
    parameter int unsigned TAG_ADDR_WIDHT = $clog2(TAG_DEPTH),
    parameter int unsigned TAG_WIDHT      = 20
) (
    input  logic                                     clk_i,
    input  logic                                     rstn_i,
    input  logic [  ICACHE_N_WAY-1:0]                req_i,
    input  logic                                     we_i,
    input  logic                                     vbit_i,
    input  logic                                     flush_i,
    input  logic [     TAG_WIDHT-1:0]                data_i,
    input  logic [TAG_ADDR_WIDHT-1:0]                addr_i,
    output logic [  ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] tag_way_o,  //- one for each way.
    output logic [  ICACHE_N_WAY-1:0]                vbit_o
);

  //- To build a memory of tags for each path.

  // Valid bit wires
  logic [TAG_DEPTH-1:0] vbit_vec[ICACHE_N_WAY-1:0];

  //--VALID bit vector
  genvar i;
  generate
    for (i = 0; i < ICACHE_N_WAY; i++) begin
      always_ff @(posedge clk_i) begin
        if (!rstn_i || flush_i) begin
          vbit_vec[i] <= '0;
          vbit_o[i]   <= '0;
        end else if (req_i[i]) begin
          if (we_i) vbit_vec[i][addr_i] <= vbit_i;
          else vbit_o[i] <= vbit_vec[i][addr_i];
        end
      end
    end
  endgenerate

  logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] mask;
  logic chip_enable;

  assign chip_enable = |req_i;

  generate
    for (genvar gv_mask = 0; gv_mask < ICACHE_N_WAY; gv_mask++) begin
      assign mask[gv_mask] = {TAG_WIDHT{req_i[gv_mask] & we_i}};
    end
  endgenerate

  tc_sram #(
      .NumWords (2 ** TAG_ADDR_WIDHT),
      .DataWidth(ICACHE_N_WAY * TAG_WIDHT),
      .ByteWidth(1),
      .NumPorts (1),
      .Latency  (1)
  ) i_tc_sram (
      .clk_i  (clk_i),
      .rst_ni (rstn_i),
      .req_i  (chip_enable),
      .we_i   (we_i),
      .addr_i (addr_i),
      .wdata_i({ICACHE_N_WAY{data_i}}),
      .be_i   (mask),
      .rdata_o(tag_way_o)
  );
endmodule

module tc_sram_wrapper #(
    parameter int unsigned NumWords = 32'd1024,  // Number of Words in data array
    parameter int unsigned DataWidth = 32'd128,  // Data signal width
    parameter int unsigned ByteWidth = 32'd8,  // Width of a data byte
    parameter int unsigned NumPorts = 32'd2,  // Number of read and write ports
    parameter int unsigned Latency = 32'd1,  // Latency when the read data is available
    parameter SimInit = "none",  // Simulation initialization
    parameter bit PrintSimCfg = 1'b0,  // Print configuration
    // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
    parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
    parameter int unsigned BeWidth = (DataWidth + ByteWidth - 32'd1) / ByteWidth,  // ceil_div
    parameter type addr_t = logic [AddrWidth-1:0],
    parameter type data_t = logic [DataWidth-1:0],
    parameter type be_t = logic [BeWidth-1:0]
) (
    input  logic                 clk_i,    // Clock
    input  logic                 rst_ni,   // Asynchronous reset active low
    // input ports
    input  logic  [NumPorts-1:0] req_i,    // request
    input  logic  [NumPorts-1:0] we_i,     // write enable
    input  addr_t [NumPorts-1:0] addr_i,   // request address
    input  data_t [NumPorts-1:0] wdata_i,  // write data
    input  be_t   [NumPorts-1:0] be_i,     // write byte enable
    // output ports
    output data_t [NumPorts-1:0] rdata_o   // read data
);

  tc_sram #(
      .NumWords(NumWords),
      .DataWidth(DataWidth),
      .ByteWidth(ByteWidth),
      .NumPorts(NumPorts),
      .Latency(Latency),
      .SimInit(SimInit),
      .PrintSimCfg(PrintSimCfg)
  ) i_tc_sram (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .req_i  (req_i),
      .we_i   (we_i),
      .be_i   (be_i),
      .wdata_i(wdata_i),
      .addr_i (addr_i),
      .rdata_o(rdata_o)
  );

endmodule
