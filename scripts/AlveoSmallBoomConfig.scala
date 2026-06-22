// AlveoSmallBoomConfig.scala
//
// Drop this file into chipyard/generators/chipyard/src/main/scala/config/
// before running  make CONFIG=AlveoSmallBoomConfig verilog
//
// Key design decisions vs. stock SmallBoomV3Config:
//   - Reset vector = 0x80000000 via WithBootROM(hang=0x80000000).
//     'hang' IS the power-on PC per PeripheralFragments.scala line 30.
//     The CPU starts directly at BRAM; the BootROM at 0x10000 is not entered.
//   - External DRAM limited to 128 KB to match our BRAM.
//     Default DRAM base in RocketChip is 0x80000000 (no override needed).
//   - SiFive UART is internal on the PBUS at 0x10020000 (DTS-verified:
//     serial@10020000 { compatible = "sifive,uart0"; }).
//     AbstractConfig includes WithNoMMIOPort (no external MMIO AXI4 port).
//     Firmware accesses UART internally at 0x10020000; DIV=867 for 100 MHz/115200.
//   - ChipTop exposes: axi4_mem_0_* (for BRAM) + uart_0_txd/rxd + JTAG + SerialTL.
//     See boom_axi_wrap.v for connections.

package chipyard

import org.chipsalliance.cde.config.{Config}
import freechips.rocketchip.subsystem._

class AlveoSmallBoomConfig extends Config(
  // BOOM V3 small out-of-order core (RV64GC, 4-wide issue)
  new boom.v3.common.WithNSmallBooms(1) ++

  // Reset vector = 0x80000000.  WithBootROM.hang IS the CPU power-on PC.
  new chipyard.config.WithBootROM(hang = BigInt("80000000", 16)) ++

  // 128 KB external memory (our BRAM) at the default RocketChip DRAM base.
  new freechips.rocketchip.subsystem.WithExtMemSize(128 * 1024) ++

  // Everything else: TileLink buses, clocks, internal UART, JTAG, SerialTL...
  new chipyard.config.AbstractConfig
)
