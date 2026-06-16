// picorv32_axi_wrap.v
// Thin wrapper around picorv32_axi that renames signals to
// Vivado-recognised AXI4-Lite naming so the BD auto-detects the interface.
// IRQ inputs are tied off; trace output is discarded.
`default_nettype none

module picorv32_axi_wrap #(
    parameter ENABLE_MUL     = 1,
    parameter ENABLE_DIV     = 1,
    parameter ENABLE_COUNTERS= 1,
    parameter COMPRESSED_ISA = 0,
    parameter ENABLE_IRQ     = 0,
    parameter [31:0] STACKADDR     = 32'h0002_0000,  // top of 128 KB BRAM
    parameter [31:0] PROGADDR_RESET= 32'h0000_0000,
    parameter [31:0] PROGADDR_IRQ  = 32'h0000_0010
) (
    input  wire        clk,
    input  wire        resetn,

    // AXI4-Lite Master — Vivado-recognised prefix "M_AXI"
    output wire        M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,
    output wire [31:0] M_AXI_AWADDR,
    output wire [2:0]  M_AXI_AWPROT,

    output wire        M_AXI_WVALID,
    input  wire        M_AXI_WREADY,
    output wire [31:0] M_AXI_WDATA,
    output wire [3:0]  M_AXI_WSTRB,

    input  wire        M_AXI_BVALID,
    output wire        M_AXI_BREADY,
    input  wire [1:0]  M_AXI_BRESP,

    output wire        M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,
    output wire [31:0] M_AXI_ARADDR,
    output wire [2:0]  M_AXI_ARPROT,

    input  wire        M_AXI_RVALID,
    output wire        M_AXI_RREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP
);

picorv32_axi #(
    .ENABLE_MUL     (ENABLE_MUL),
    .ENABLE_DIV     (ENABLE_DIV),
    .ENABLE_COUNTERS(ENABLE_COUNTERS),
    .COMPRESSED_ISA (COMPRESSED_ISA),
    .ENABLE_IRQ     (ENABLE_IRQ),
    .STACKADDR      (STACKADDR),
    .PROGADDR_RESET (PROGADDR_RESET),
    .PROGADDR_IRQ   (PROGADDR_IRQ)
) cpu (
    .clk    (clk),
    .resetn (resetn),

    .mem_axi_awvalid(M_AXI_AWVALID),
    .mem_axi_awready(M_AXI_AWREADY),
    .mem_axi_awaddr (M_AXI_AWADDR),
    .mem_axi_awprot (M_AXI_AWPROT),

    .mem_axi_wvalid (M_AXI_WVALID),
    .mem_axi_wready (M_AXI_WREADY),
    .mem_axi_wdata  (M_AXI_WDATA),
    .mem_axi_wstrb  (M_AXI_WSTRB),

    .mem_axi_bvalid (M_AXI_BVALID),
    .mem_axi_bready (M_AXI_BREADY),

    .mem_axi_arvalid(M_AXI_ARVALID),
    .mem_axi_arready(M_AXI_ARREADY),
    .mem_axi_araddr (M_AXI_ARADDR),
    .mem_axi_arprot (M_AXI_ARPROT),

    .mem_axi_rvalid (M_AXI_RVALID),
    .mem_axi_rready (M_AXI_RREADY),
    .mem_axi_rdata  (M_AXI_RDATA),

    // bresp/rresp: picorv32_axi ignores these but accept them
    .irq    (32'b0),
    .eoi    (),
    .trace_valid(),
    .trace_data ()
);

endmodule
`default_nettype wire
