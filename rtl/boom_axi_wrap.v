// boom_axi_wrap.v
//
// Adapter between Chipyard-generated ChipTop (AlveoSmallBoomConfig) and soc.v.
//
// Port names verified from generated rtl/boom_gen/ChipTop.sv:
//
//   Clock/Reset   : clock_uncore (in), reset_io (in, active-high)
//   AXI4 Memory   : axi4_mem_0_bits_*  -- 64-bit data, 32-bit address
//   UART          : uart_0_txd (out), uart_0_rxd (in)
//   JTAG          : jtag_TCK/TMS/TDI (in), jtag_TDO (out), jtag_reset (in)
//   SerialTL      : serial_tl_0_in/out_* + serial_tl_0_clock_in
//   Other         : custom_boot (in), clock_tap (out), axi4_mem_0_clock (out)
//
// Address note:
//   ChipTop exposes a 32-bit AXI4 address (BOOM's physical address space).
//   MEM_AWADDR/MEM_ARADDR here are 64-bit (zero-extended) for soc.v compatibility.
`default_nettype none

module boom_axi_wrap (
    input  wire clk,
    input  wire rstn,   // active-low; inverted to active-high reset_io inside

    // ── MEM port : AXI4 64-bit data, 32-bit addr, 4-bit ID ──────────────────
    output wire        MEM_AWVALID,
    input  wire        MEM_AWREADY,
    output wire [63:0] MEM_AWADDR,   // zero-extended from ChipTop's [31:0]
    output wire [ 3:0] MEM_AWID,
    output wire [ 7:0] MEM_AWLEN,
    output wire [ 2:0] MEM_AWSIZE,
    output wire [ 1:0] MEM_AWBURST,
    output wire        MEM_AWLOCK,
    output wire [ 3:0] MEM_AWCACHE,
    output wire [ 2:0] MEM_AWPROT,
    output wire [ 3:0] MEM_AWQOS,

    output wire        MEM_WVALID,
    input  wire        MEM_WREADY,
    output wire [63:0] MEM_WDATA,
    output wire [ 7:0] MEM_WSTRB,
    output wire        MEM_WLAST,

    input  wire        MEM_BVALID,
    output wire        MEM_BREADY,
    input  wire [ 3:0] MEM_BID,
    input  wire [ 1:0] MEM_BRESP,

    output wire        MEM_ARVALID,
    input  wire        MEM_ARREADY,
    output wire [63:0] MEM_ARADDR,   // zero-extended from ChipTop's [31:0]
    output wire [ 3:0] MEM_ARID,
    output wire [ 7:0] MEM_ARLEN,
    output wire [ 2:0] MEM_ARSIZE,
    output wire [ 1:0] MEM_ARBURST,
    output wire        MEM_ARLOCK,
    output wire [ 3:0] MEM_ARCACHE,
    output wire [ 2:0] MEM_ARPROT,
    output wire [ 3:0] MEM_ARQOS,

    input  wire        MEM_RVALID,
    output wire        MEM_RREADY,
    input  wire [ 3:0] MEM_RID,
    input  wire [63:0] MEM_RDATA,
    input  wire [ 1:0] MEM_RRESP,
    input  wire        MEM_RLAST,

    // ── SiFive UART (internal to ChipTop, PBUS at 0x62100000) ───────────────
    output wire uart_tx,
    input  wire uart_rx
);

// Zero-extend ChipTop's 32-bit addresses to 64-bit for soc.v
wire [31:0] ct_aw_addr, ct_ar_addr;
assign MEM_AWADDR = {32'b0, ct_aw_addr};
assign MEM_ARADDR = {32'b0, ct_ar_addr};

// ── ChipTop instantiation ─────────────────────────────────────────────────────
ChipTop boom_cpu (
    // Clock and reset
    .clock_uncore                   (clk),
    .reset_io                       (~rstn),    // active-high in Chisel

    // ── AXI4 memory port ──────────────────────────────────────────────────────
    // axi4_mem_0_clock is an output (ChipTop's memory domain clock).
    // We drive both sides from the same clk so it can be left unconnected.

    .axi4_mem_0_bits_aw_valid       (MEM_AWVALID),
    .axi4_mem_0_bits_aw_ready       (MEM_AWREADY),
    .axi4_mem_0_bits_aw_bits_id     (MEM_AWID),
    .axi4_mem_0_bits_aw_bits_addr   (ct_aw_addr),
    .axi4_mem_0_bits_aw_bits_len    (MEM_AWLEN),
    .axi4_mem_0_bits_aw_bits_size   (MEM_AWSIZE),
    .axi4_mem_0_bits_aw_bits_burst  (MEM_AWBURST),
    .axi4_mem_0_bits_aw_bits_lock   (MEM_AWLOCK),
    .axi4_mem_0_bits_aw_bits_cache  (MEM_AWCACHE),
    .axi4_mem_0_bits_aw_bits_prot   (MEM_AWPROT),
    .axi4_mem_0_bits_aw_bits_qos    (MEM_AWQOS),

    .axi4_mem_0_bits_w_valid        (MEM_WVALID),
    .axi4_mem_0_bits_w_ready        (MEM_WREADY),
    .axi4_mem_0_bits_w_bits_data    (MEM_WDATA),
    .axi4_mem_0_bits_w_bits_strb    (MEM_WSTRB),
    .axi4_mem_0_bits_w_bits_last    (MEM_WLAST),

    .axi4_mem_0_bits_b_ready        (MEM_BREADY),
    .axi4_mem_0_bits_b_valid        (MEM_BVALID),
    .axi4_mem_0_bits_b_bits_id      (MEM_BID),
    .axi4_mem_0_bits_b_bits_resp    (MEM_BRESP),

    .axi4_mem_0_bits_ar_valid       (MEM_ARVALID),
    .axi4_mem_0_bits_ar_ready       (MEM_ARREADY),
    .axi4_mem_0_bits_ar_bits_id     (MEM_ARID),
    .axi4_mem_0_bits_ar_bits_addr   (ct_ar_addr),
    .axi4_mem_0_bits_ar_bits_len    (MEM_ARLEN),
    .axi4_mem_0_bits_ar_bits_size   (MEM_ARSIZE),
    .axi4_mem_0_bits_ar_bits_burst  (MEM_ARBURST),
    .axi4_mem_0_bits_ar_bits_lock   (MEM_ARLOCK),
    .axi4_mem_0_bits_ar_bits_cache  (MEM_ARCACHE),
    .axi4_mem_0_bits_ar_bits_prot   (MEM_ARPROT),
    .axi4_mem_0_bits_ar_bits_qos    (MEM_ARQOS),

    .axi4_mem_0_bits_r_ready        (MEM_RREADY),
    .axi4_mem_0_bits_r_valid        (MEM_RVALID),
    .axi4_mem_0_bits_r_bits_id      (MEM_RID),
    .axi4_mem_0_bits_r_bits_data    (MEM_RDATA),
    .axi4_mem_0_bits_r_bits_resp    (MEM_RRESP),
    .axi4_mem_0_bits_r_bits_last    (MEM_RLAST),

    // ── UART pins ─────────────────────────────────────────────────────────────
    .uart_0_txd                     (uart_tx),
    .uart_0_rxd                     (uart_rx),

    // ── JTAG (tied off -- debug not needed on FPGA) ───────────────────────────
    .jtag_TCK                       (1'b0),
    .jtag_TMS                       (1'b1),   // keeps TAP in Test-Logic-Reset
    .jtag_TDI                       (1'b0),
    // .jtag_TDO                    (),       // output, left open
    .jtag_reset                     (1'b1),   // hold JTAG reset asserted

    // ── SerialTL (tied off -- not used) ───────────────────────────────────────
    .serial_tl_0_in_valid           (1'b0),
    .serial_tl_0_in_bits_phit       (32'b0),
    // .serial_tl_0_in_ready        (),       // output, left open
    .serial_tl_0_out_ready          (1'b0),
    // .serial_tl_0_out_valid       (),       // output, left open
    // .serial_tl_0_out_bits_phit   (),       // output, left open
    .serial_tl_0_clock_in           (1'b0),   // unused serial clock, tie low

    // ── Custom boot (0 = CPU boots from BootROM hang address = 0x80000000) ────
    .custom_boot                    (1'b0)

    // ── Clock tap output (left open) ──────────────────────────────────────────
    // .clock_tap                   ()
    // ── Memory domain clock output (left open, same domain as clock_uncore) ───
    // .axi4_mem_0_clock            ()
);

endmodule
`default_nettype wire
