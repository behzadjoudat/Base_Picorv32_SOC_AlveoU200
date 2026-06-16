# =============================================================================
# alveo_u200.xdc — Pin and timing constraints for Alveo U200
# Part: xcu200-fsgd2104-2-e
#
# Pins verified from:
#   $XILINX_VIVADO/data/boards/board_files/au200/1.3/part0_pins.xml
#
# Top module ports (rtl/top.v): sys_clk_p, sys_clk_n, uart_txd, uart_rxd
# =============================================================================

# ---- System clock : 300 MHz LVDS, bank 72 (AY37/AY38) ----------------------
# The U200 has no on-board 100 MHz clock.  The 300 MHz oscillator is divided
# to 100 MHz by the MMCME4_BASE in rtl/top.v.
set_property -dict {PACKAGE_PIN AY37 IOSTANDARD LVDS} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN AY38 IOSTANDARD LVDS} [get_ports sys_clk_n]

create_clock -period 3.333 -name sys_clk [get_ports sys_clk_p]

# ---- UART : USB-UART bridge (BB20/BF18, bank 64, LVCMOS12) -----------------
# USB_UART_TX (BB20): FT4232 TX → FPGA RX direction is swapped in the bridge;
#   from the FPGA side, BB20 is the pin the FPGA drives (TXD).
# USB_UART_RX (BF18): FPGA receives from the bridge on this pin (RXD).
set_property -dict {PACKAGE_PIN BB20 IOSTANDARD LVCMOS12} [get_ports uart_txd]
set_property -dict {PACKAGE_PIN BF18 IOSTANDARD LVCMOS12} [get_ports uart_rxd]

# ---- Bitstream configuration ------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_VOLTAGE           1.8    [current_design]
set_property CFGBVS                   GND    [current_design]

# ---- Timing exceptions ------------------------------------------------------
# UART TX/RX are I/O-rate constrained by the UART controller, not the
# system clock; false-path them to suppress spurious timing warnings.
set_false_path -to   [get_ports uart_txd]
set_false_path -from [get_ports uart_rxd]
