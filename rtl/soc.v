// soc.v -- BOOM Out-of-Order SoC
//
// Memory map  (Chipyard AlveoSmallBoomConfig)
//   0x8000_0000 - 0x8001_FFFF  128 KB BRAM  -- MEM port (AXI4, 64-bit, cache backing)
//   0x1002_0000 - 0x1002_001C  SiFive UART  -- internal to ChipTop on PBUS (DTS-verified)
//
// Bus topology
//   BOOM MEM port (AXI4, 64-bit, 4-bit ID) ---> axi_bram_ctrl_0 ---> blk_mem_gen_0
//   UART TX/RX pins pass straight through from boom_axi_wrap to soc ports.
//     (UART is internal in ChipTop; no external MMIO AXI4 port with AbstractConfig.)
//
// BRAM sizing for 64-bit bus
//   axi_bram_ctrl_0: DATA_WIDTH=64, ID_WIDTH=4, MEM_DEPTH=16384
//   blk_mem_gen_0:   64-bit wide, 16384 deep = 128 KB
//   Byte address from ctrl: 17 bits
//   Word address to BMG:    bram_addr[16:3]  (/ 8, gives 14-bit index)
//   Byte enables:           8 bits (one per byte in 64-bit word)
`default_nettype none

module soc (
    input  wire clk,
    input  wire rstn,
    output wire uart_tx,
    input  wire uart_rx
);

// =========================================================================
// BOOM AXI4 MEM wires (64-bit, 4-bit ID)
// =========================================================================
wire        mem_awvalid;  wire mem_awready;
wire [63:0] mem_awaddr;   wire [3:0] mem_awid;
wire [ 7:0] mem_awlen;    wire [2:0] mem_awsize;   wire [1:0] mem_awburst;
wire        mem_awlock;   wire [3:0] mem_awcache;  wire [2:0] mem_awprot;
wire [ 3:0] mem_awqos;

wire        mem_wvalid;   wire mem_wready;
wire [63:0] mem_wdata;    wire [7:0] mem_wstrb;    wire mem_wlast;

wire        mem_bvalid;   wire mem_bready;
wire [ 3:0] mem_bid;      wire [1:0] mem_bresp;

wire        mem_arvalid;  wire mem_arready;
wire [63:0] mem_araddr;   wire [3:0] mem_arid;
wire [ 7:0] mem_arlen;    wire [2:0] mem_arsize;   wire [1:0] mem_arburst;
wire        mem_arlock;   wire [3:0] mem_arcache;  wire [2:0] mem_arprot;
wire [ 3:0] mem_arqos;

wire        mem_rvalid;   wire mem_rready;
wire [ 3:0] mem_rid;      wire [63:0] mem_rdata;
wire [ 1:0] mem_rresp;    wire mem_rlast;

// =========================================================================
// BOOM CPU (boom_axi_wrap wraps ChipTop from gen_boom.sh)
// UART pins are internal in ChipTop; boom_axi_wrap exposes uart_tx/uart_rx.
// =========================================================================
boom_axi_wrap cpu (
    .clk         (clk),
    .rstn        (rstn),

    .MEM_AWVALID (mem_awvalid),  .MEM_AWREADY (mem_awready),
    .MEM_AWADDR  (mem_awaddr),   .MEM_AWID    (mem_awid),
    .MEM_AWLEN   (mem_awlen),    .MEM_AWSIZE  (mem_awsize),
    .MEM_AWBURST (mem_awburst),  .MEM_AWLOCK  (mem_awlock),
    .MEM_AWCACHE (mem_awcache),  .MEM_AWPROT  (mem_awprot),
    .MEM_AWQOS   (mem_awqos),

    .MEM_WVALID  (mem_wvalid),   .MEM_WREADY  (mem_wready),
    .MEM_WDATA   (mem_wdata),    .MEM_WSTRB   (mem_wstrb),
    .MEM_WLAST   (mem_wlast),

    .MEM_BVALID  (mem_bvalid),   .MEM_BREADY  (mem_bready),
    .MEM_BID     (mem_bid),      .MEM_BRESP   (mem_bresp),

    .MEM_ARVALID (mem_arvalid),  .MEM_ARREADY (mem_arready),
    .MEM_ARADDR  (mem_araddr),   .MEM_ARID    (mem_arid),
    .MEM_ARLEN   (mem_arlen),    .MEM_ARSIZE  (mem_arsize),
    .MEM_ARBURST (mem_arburst),  .MEM_ARLOCK  (mem_arlock),
    .MEM_ARCACHE (mem_arcache),  .MEM_ARPROT  (mem_arprot),
    .MEM_ARQOS   (mem_arqos),

    .MEM_RVALID  (mem_rvalid),   .MEM_RREADY  (mem_rready),
    .MEM_RID     (mem_rid),      .MEM_RDATA   (mem_rdata),
    .MEM_RRESP   (mem_rresp),    .MEM_RLAST   (mem_rlast),

    .uart_tx     (uart_tx),
    .uart_rx     (uart_rx)
);

// =========================================================================
// MEM port --> AXI BRAM Controller (AXI4, 64-bit)
//   axi_bram_ctrl_0: DATA_WIDTH=64, ID_WIDTH=4, MEM_DEPTH=16384
//   BRAM window: lower 17 address bits (128 KB starting at 0x80000000)
// =========================================================================
wire        bram_clk_a, bram_rst_a, bram_en_a;
wire [ 7:0] bram_we_a;
wire [16:0] bram_addr_a;
wire [63:0] bram_wrdata_a, bram_rddata_a;

wire        bram_clk_b, bram_rst_b, bram_en_b;
wire [ 7:0] bram_we_b;
wire [16:0] bram_addr_b;
wire [63:0] bram_wrdata_b, bram_rddata_b;

axi_bram_ctrl_0 bram_ctrl (
    .s_axi_aclk    (clk),
    .s_axi_aresetn (rstn),

    .s_axi_awaddr  (mem_awaddr[16:0]),
    .s_axi_awid    (mem_awid),
    .s_axi_awlen   (mem_awlen),
    .s_axi_awsize  (mem_awsize),
    .s_axi_awburst (mem_awburst),
    .s_axi_awlock  (mem_awlock),
    .s_axi_awcache (mem_awcache),
    .s_axi_awprot  (mem_awprot),
    .s_axi_awvalid (mem_awvalid),
    .s_axi_awready (mem_awready),

    .s_axi_wdata   (mem_wdata),
    .s_axi_wstrb   (mem_wstrb),
    .s_axi_wlast   (mem_wlast),
    .s_axi_wvalid  (mem_wvalid),
    .s_axi_wready  (mem_wready),

    .s_axi_bid     (mem_bid),
    .s_axi_bresp   (mem_bresp),
    .s_axi_bvalid  (mem_bvalid),
    .s_axi_bready  (mem_bready),

    .s_axi_araddr  (mem_araddr[16:0]),
    .s_axi_arid    (mem_arid),
    .s_axi_arlen   (mem_arlen),
    .s_axi_arsize  (mem_arsize),
    .s_axi_arburst (mem_arburst),
    .s_axi_arlock  (mem_arlock),
    .s_axi_arcache (mem_arcache),
    .s_axi_arprot  (mem_arprot),
    .s_axi_arvalid (mem_arvalid),
    .s_axi_arready (mem_arready),

    .s_axi_rid     (mem_rid),
    .s_axi_rdata   (mem_rdata),
    .s_axi_rresp   (mem_rresp),
    .s_axi_rlast   (mem_rlast),
    .s_axi_rvalid  (mem_rvalid),
    .s_axi_rready  (mem_rready),

    .bram_rst_a    (bram_rst_a), .bram_clk_a (bram_clk_a),
    .bram_en_a     (bram_en_a),  .bram_we_a  (bram_we_a),
    .bram_addr_a   (bram_addr_a),
    .bram_wrdata_a (bram_wrdata_a), .bram_rddata_a (bram_rddata_a),

    .bram_rst_b    (bram_rst_b), .bram_clk_b (bram_clk_b),
    .bram_en_b     (bram_en_b),  .bram_we_b  (bram_we_b),
    .bram_addr_b   (bram_addr_b),
    .bram_wrdata_b (bram_wrdata_b), .bram_rddata_b (bram_rddata_b)
);

// =========================================================================
// Block Memory Generator -- blk_mem_gen_0
//   True Dual Port, 16384 x 64-bit = 128 KB, initialized from firmware.coe
//   bram_addr from ctrl is 17-bit byte address; BMG takes 14-bit word index.
//   Word index = byte_addr >> 3  -->  bram_addr[16:3]
// =========================================================================
blk_mem_gen_0 bram_mem (
    .clka  (bram_clk_a), .ena   (bram_en_a),
    .wea   (bram_we_a),  .addra (bram_addr_a[16:3]),
    .dina  (bram_wrdata_a), .douta (bram_rddata_a),

    .clkb  (bram_clk_b), .enb   (bram_en_b),
    .web   (bram_we_b),  .addrb (bram_addr_b[16:3]),
    .dinb  (bram_wrdata_b), .doutb (bram_rddata_b)
);

endmodule
`default_nettype wire
