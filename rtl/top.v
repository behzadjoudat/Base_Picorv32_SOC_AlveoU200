// top.v — Alveo U200 board wrapper
//
// The on-board oscillator provides a 300 MHz LVDS clock at AY37/AY38.
// An MMCME4_BASE divides it to 100 MHz for the SoC.
// VCO = 300 * 3 / 1 = 900 MHz; CLKOUT0 = 900 / 9 = 100 MHz.
`default_nettype none

module top (
    input  wire sys_clk_p,     // AY37  300 MHz LVDS
    input  wire sys_clk_n,     // AY38
    output wire uart_txd,      // BB20  LVCMOS12 → USB-UART bridge
    input  wire uart_rxd       // BF18  LVCMOS12 ← USB-UART bridge
);

// ---- IBUFDS: differential clock input -----------------------------------
wire clk_ibuf;
IBUFDS u_ibufds (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_ibuf));

// ---- MMCME4_BASE: 300 MHz → 100 MHz ------------------------------------
wire clkout0, clkfb_out, clkfb_buf, clk;
wire mmcm_locked;

MMCME4_BASE #(
    .BANDWIDTH       ("OPTIMIZED"),
    .CLKIN1_PERIOD   (3.333),     // 300 MHz = 3.333 ns
    .CLKFBOUT_MULT_F (3.000),     // VCO = 300 * 3 = 900 MHz
    .DIVCLK_DIVIDE   (1),
    .CLKOUT0_DIVIDE_F(9.000),     // CLKOUT0 = 900 / 9 = 100 MHz
    .CLKOUT0_DUTY_CYCLE(0.500),
    .CLKOUT0_PHASE   (0.000),
    .CLKFBOUT_PHASE  (0.000),
    .STARTUP_WAIT    ("FALSE")
) u_mmcm (
    .CLKIN1    (clk_ibuf),
    .CLKFBIN   (clkfb_buf),
    .CLKOUT0   (clkout0),
    .CLKOUT0B  (),
    .CLKFBOUT  (clkfb_out),
    .CLKFBOUTB (),
    .LOCKED    (mmcm_locked),
    .PWRDWN    (1'b0),
    .RST       (1'b0)
);

BUFG u_bufg_fb  (.I(clkfb_out), .O(clkfb_buf));
BUFG u_bufg_clk (.I(clkout0),   .O(clk));

// ---- Power-on reset: 128 cycles after MMCM locks -----------------------
reg [7:0] rst_cnt = 8'h00;
wire      rstn = rst_cnt[7];

always @(posedge clk or negedge mmcm_locked)
    if      (!mmcm_locked) rst_cnt <= 8'h00;
    else if (!rstn)        rst_cnt <= rst_cnt + 8'd1;

// ---- SoC ----------------------------------------------------------------
soc u_soc (
    .clk    (clk),
    .rstn   (rstn),
    .uart_tx(uart_txd),
    .uart_rx(uart_rxd)
);

endmodule
`default_nettype wire
