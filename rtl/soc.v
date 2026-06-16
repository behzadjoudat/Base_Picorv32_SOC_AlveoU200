// soc.v — PicoRV32 AXI4-Lite SoC
//
// Memory map
//   0x0000_0000 – 0x0001_FFFF  128 KB BRAM  (axi_bram_ctrl_0 + blk_mem_gen_0)
//   0x4060_0000 – 0x4060_000F   16 B  UART   (axi_uartlite_0)
//
// Address-decoder notes:
//   • picorv32_axi presents AW and W simultaneously on every write
//   • only one outstanding transaction at a time (no pipelining)
//   → a combinatorial 2-slave decoder suffices; only B and R routing
//     needs a single registered bit to remember which slave owns the response.
//
// IP port-width assumptions (axi_bram_ctrl_0 configured with
//   DATA_WIDTH=32, MEM_DEPTH=32768 words, ID_WIDTH=0):
//   s_axi_awaddr / araddr : 17 bits  (byte address, log2(128KB) = 17)
//   bram_addr_a/b output  : 17 bits  (byte address — controller does NOT shift)
//   blk_mem_gen_0 addra/b : 15 bits  (word address, log2(32768) = 15)
//   → connection: addra = bram_addr_a[16:2]  (>> 2, drops byte-select bits)
`default_nettype none

module soc (
    input  wire clk,
    input  wire rstn,
    output wire uart_tx,
    input  wire uart_rx
);

// =========================================================================
// PicoRV32 AXI4-Lite master
// =========================================================================
wire        cpu_awvalid, cpu_awready;
wire [31:0] cpu_awaddr;
wire [2:0]  cpu_awprot;

wire        cpu_wvalid, cpu_wready;
wire [31:0] cpu_wdata;
wire [3:0]  cpu_wstrb;

wire        cpu_bvalid, cpu_bready;
wire [1:0]  cpu_bresp;

wire        cpu_arvalid, cpu_arready;
wire [31:0] cpu_araddr;
wire [2:0]  cpu_arprot;

wire        cpu_rvalid, cpu_rready;
wire [31:0] cpu_rdata;
wire [1:0]  cpu_rresp;

picorv32_axi_wrap cpu (
    .clk           (clk),
    .resetn        (rstn),
    .M_AXI_AWVALID (cpu_awvalid),
    .M_AXI_AWREADY (cpu_awready),
    .M_AXI_AWADDR  (cpu_awaddr),
    .M_AXI_AWPROT  (cpu_awprot),
    .M_AXI_WVALID  (cpu_wvalid),
    .M_AXI_WREADY  (cpu_wready),
    .M_AXI_WDATA   (cpu_wdata),
    .M_AXI_WSTRB   (cpu_wstrb),
    .M_AXI_BVALID  (cpu_bvalid),
    .M_AXI_BREADY  (cpu_bready),
    .M_AXI_BRESP   (cpu_bresp),
    .M_AXI_ARVALID (cpu_arvalid),
    .M_AXI_ARREADY (cpu_arready),
    .M_AXI_ARADDR  (cpu_araddr),
    .M_AXI_ARPROT  (cpu_arprot),
    .M_AXI_RVALID  (cpu_rvalid),
    .M_AXI_RREADY  (cpu_rready),
    .M_AXI_RDATA   (cpu_rdata),
    .M_AXI_RRESP   (cpu_rresp)
);

// =========================================================================
// AXI4-Lite address decoder — 1 master → 2 slaves
// =========================================================================

// --- decode ---------------------------------------------------------------
wire aw_to_bram = (cpu_awaddr[31:17] == 15'h0);
wire ar_to_bram = (cpu_araddr[31:17] == 15'h0);

// --- AW channel -----------------------------------------------------------
wire bram_awvalid, bram_awready;
wire uart_awvalid, uart_awready;

assign bram_awvalid = cpu_awvalid &  aw_to_bram;
assign uart_awvalid = cpu_awvalid & ~aw_to_bram;
assign cpu_awready  = aw_to_bram ? bram_awready : uart_awready;

// --- W channel (always simultaneous with AW for picorv32_axi) ------------
wire bram_wvalid, bram_wready;
wire uart_wvalid, uart_wready;

assign bram_wvalid = cpu_wvalid &  aw_to_bram;
assign uart_wvalid = cpu_wvalid & ~aw_to_bram;
assign cpu_wready  = aw_to_bram ? bram_wready : uart_wready;

// --- B channel (write response) -------------------------------------------
wire        bram_bvalid, bram_bready;
wire [1:0]  bram_bresp;
wire        uart_bvalid, uart_bready;
wire [1:0]  uart_bresp;

reg b_from_uart;
always @(posedge clk or negedge rstn)
    if      (!rstn)                      b_from_uart <= 1'b0;
    else if (cpu_awvalid && cpu_awready) b_from_uart <= ~aw_to_bram;

assign cpu_bvalid  = b_from_uart ? uart_bvalid : bram_bvalid;
assign cpu_bresp   = b_from_uart ? uart_bresp  : bram_bresp;
assign bram_bready = cpu_bready & ~b_from_uart;
assign uart_bready = cpu_bready &  b_from_uart;

// --- AR channel -----------------------------------------------------------
wire bram_arvalid, bram_arready;
wire uart_arvalid, uart_arready;

assign bram_arvalid = cpu_arvalid &  ar_to_bram;
assign uart_arvalid = cpu_arvalid & ~ar_to_bram;
assign cpu_arready  = ar_to_bram ? bram_arready : uart_arready;

// --- R channel (read data) ------------------------------------------------
wire        bram_rvalid, bram_rready;
wire [31:0] bram_rdata;
wire [1:0]  bram_rresp;
wire        uart_rvalid, uart_rready;
wire [31:0] uart_rdata;
wire [1:0]  uart_rresp;

reg r_from_uart;
always @(posedge clk or negedge rstn)
    if      (!rstn)                      r_from_uart <= 1'b0;
    else if (cpu_arvalid && cpu_arready) r_from_uart <= ~ar_to_bram;

assign cpu_rvalid  = r_from_uart ? uart_rvalid : bram_rvalid;
assign cpu_rdata   = r_from_uart ? uart_rdata  : bram_rdata;
assign cpu_rresp   = r_from_uart ? uart_rresp  : bram_rresp;
assign bram_rready = cpu_rready & ~r_from_uart;
assign uart_rready = cpu_rready &  r_from_uart;

// =========================================================================
// Xilinx AXI BRAM Controller — axi_bram_ctrl_0
//   Configured: DATA_WIDTH=32, MEM_DEPTH=32768, ID_WIDTH=0
//   AXI  side:  17-bit byte address  (log2(128 KB) = 17)
//   BRAM side:  17-bit byte address output from controller
//               → BMG addra/addrb = bram_addr[16:2]  (15-bit word addr)
//               bram_rst_a/b: driven by controller but BMG has no rst pin
//               when output register is disabled — declared but unconnected.
// =========================================================================
wire        bram_clk_a, bram_rst_a, bram_en_a;
wire [3:0]  bram_we_a;
wire [16:0] bram_addr_a;          // 17-bit byte address from controller
wire [31:0] bram_wrdata_a, bram_rddata_a;

wire        bram_clk_b, bram_rst_b, bram_en_b;
wire [3:0]  bram_we_b;
wire [16:0] bram_addr_b;          // 17-bit byte address from controller
wire [31:0] bram_wrdata_b, bram_rddata_b;

axi_bram_ctrl_0 bram_ctrl (
    .s_axi_aclk   (clk),
    .s_axi_aresetn(rstn),

    // Write address (17-bit byte offset into 128 KB BRAM)
    .s_axi_awaddr (cpu_awaddr[16:0]),
    .s_axi_awlen  (8'b0),
    .s_axi_awsize (3'b010),     // 4-byte transfer
    .s_axi_awburst(2'b01),      // INCR (irrelevant for single beat)
    .s_axi_awlock (1'b0),
    .s_axi_awcache(4'b0),
    .s_axi_awprot (cpu_awprot),
    .s_axi_awvalid(bram_awvalid),
    .s_axi_awready(bram_awready),

    // Write data
    .s_axi_wdata  (cpu_wdata),
    .s_axi_wstrb  (cpu_wstrb),
    .s_axi_wlast  (1'b1),
    .s_axi_wvalid (bram_wvalid),
    .s_axi_wready (bram_wready),

    // Write response
    .s_axi_bresp  (bram_bresp),
    .s_axi_bvalid (bram_bvalid),
    .s_axi_bready (bram_bready),

    // Read address
    .s_axi_araddr (cpu_araddr[16:0]),
    .s_axi_arlen  (8'b0),
    .s_axi_arsize (3'b010),
    .s_axi_arburst(2'b01),
    .s_axi_arlock (1'b0),
    .s_axi_arcache(4'b0),
    .s_axi_arprot (cpu_arprot),
    .s_axi_arvalid(bram_arvalid),
    .s_axi_arready(bram_arready),

    // Read data
    .s_axi_rdata  (bram_rdata),
    .s_axi_rresp  (bram_rresp),
    .s_axi_rlast  (),
    .s_axi_rvalid (bram_rvalid),
    .s_axi_rready (bram_rready),

    // Native BRAM port A (write channel)
    .bram_rst_a   (bram_rst_a),
    .bram_clk_a   (bram_clk_a),
    .bram_en_a    (bram_en_a),
    .bram_we_a    (bram_we_a),
    .bram_addr_a  (bram_addr_a),
    .bram_wrdata_a(bram_wrdata_a),
    .bram_rddata_a(bram_rddata_a),

    // Native BRAM port B (read channel)
    .bram_rst_b   (bram_rst_b),
    .bram_clk_b   (bram_clk_b),
    .bram_en_b    (bram_en_b),
    .bram_we_b    (bram_we_b),
    .bram_addr_b  (bram_addr_b),
    .bram_wrdata_b(bram_wrdata_b),
    .bram_rddata_b(bram_rddata_b)
);

// =========================================================================
// Xilinx Block Memory Generator — blk_mem_gen_0
//   True Dual Port RAM, 32768 × 32-bit = 128 KB
//   Initialised from firmware.coe at synthesis time
// =========================================================================
blk_mem_gen_0 bram_mem (
    // Port A — write
    .clka (bram_clk_a),
    .ena  (bram_en_a),
    .wea  (bram_we_a),
    .addra(bram_addr_a[16:2]),   // byte→word: drop byte-select bits [1:0]
    .dina (bram_wrdata_a),
    .douta(bram_rddata_a),

    // Port B — read
    .clkb (bram_clk_b),
    .enb  (bram_en_b),
    .web  (bram_we_b),
    .addrb(bram_addr_b[16:2]),   // byte→word: drop byte-select bits [1:0]
    .dinb (bram_wrdata_b),
    .doutb(bram_rddata_b)
);

// =========================================================================
// Xilinx AXI UART Lite — axi_uartlite_0
//   115200 baud, 8N1 — base address 0x40600000
//   Address port is 4 bits (covers 4 registers × 4 bytes = 16 B)
// =========================================================================
axi_uartlite_0 uart_lite (
    .s_axi_aclk   (clk),
    .s_axi_aresetn(rstn),

    .s_axi_awaddr (cpu_awaddr[3:0]),
    .s_axi_awvalid(uart_awvalid),
    .s_axi_awready(uart_awready),

    .s_axi_wdata  (cpu_wdata),
    .s_axi_wstrb  (cpu_wstrb),
    .s_axi_wvalid (uart_wvalid),
    .s_axi_wready (uart_wready),

    .s_axi_bresp  (uart_bresp),
    .s_axi_bvalid (uart_bvalid),
    .s_axi_bready (uart_bready),

    .s_axi_araddr (cpu_araddr[3:0]),
    .s_axi_arvalid(uart_arvalid),
    .s_axi_arready(uart_arready),

    .s_axi_rdata  (uart_rdata),
    .s_axi_rresp  (uart_rresp),
    .s_axi_rvalid (uart_rvalid),
    .s_axi_rready (uart_rready),

    .rx           (uart_rx),
    .tx           (uart_tx),
    .interrupt    ()
);

endmodule
`default_nettype wire
