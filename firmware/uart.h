#ifndef UART_H
#define UART_H
#include <stdint.h>

/* SiFive UART register map (Freedom E SDK reference)
 * Address verified from generated DTS:
 *   serial@10020000 { compatible = "sifive,uart0"; reg = <0x10020000 0x1000>; }
 * AlveoSmallBoomConfig uses Chipyard's WithUART which places the SiFive
 * UART on the PBUS.  WithNoMMIOPort means there is NO external MMIO AXI4 port;
 * the UART is internal to ChipTop and accessed via TileLink at 0x10020000.
 *
 * Baud divisor: ChipTop receives clock_uncore = 100 MHz (our MMCM output).
 * All TileLink buses run at the same clock, so PBUS = 100 MHz.
 * DIV = 100_000_000 / 115200 - 1 = 867.
 *
 * Call uart_init() first -- it programs the divisor and enables TX/RX.
 */
#define UART_BASE    0x10020000UL

#define UART_TXDATA  (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_RXDATA  (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_TXCTRL  (*(volatile uint32_t *)(UART_BASE + 0x08))
#define UART_RXCTRL  (*(volatile uint32_t *)(UART_BASE + 0x0C))
#define UART_IE      (*(volatile uint32_t *)(UART_BASE + 0x10))
#define UART_IP      (*(volatile uint32_t *)(UART_BASE + 0x14))
#define UART_DIV     (*(volatile uint32_t *)(UART_BASE + 0x18))

/* TXDATA: bit 31 = TX FIFO full (do not write when set) */
#define UART_TXDATA_FULL    (1u << 31)

/* RXDATA: bit 31 = RX FIFO empty (data field invalid when set) */
#define UART_RXDATA_EMPTY   (1u << 31)

/* TXCTRL: bit 0 = TX enable */
#define UART_TXCTRL_TXEN    (1u << 0)

/* RXCTRL: bit 0 = RX enable */
#define UART_RXCTRL_RXEN    (1u << 0)

/* DIV: baud-rate divisor = (f_clk / baud) - 1
 *   At 100 MHz clock, 115200 baud: divisor = 100000000/115200 - 1 = 867 */
#define UART_DIV_115200     867u

void uart_init(void);
void uart_putc(char c);
void uart_puts(const char *s);
int  uart_getc(void);   /* blocking receive */

#endif /* UART_H */
