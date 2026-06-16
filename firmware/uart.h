#ifndef UART_H
#define UART_H
#include <stdint.h>

/* Xilinx AXI UART Lite v2.0 register map (PG142)
 * Base address assigned by SmartConnect: 0x40600000
 */
#define UART_BASE   0x40600000UL

#define UART_RX     (*(volatile uint32_t *)(UART_BASE + 0x00))  /* receive FIFO  */
#define UART_TX     (*(volatile uint32_t *)(UART_BASE + 0x04))  /* transmit FIFO */
#define UART_STAT   (*(volatile uint32_t *)(UART_BASE + 0x08))  /* status reg    */
#define UART_CTRL   (*(volatile uint32_t *)(UART_BASE + 0x0C))  /* control reg   */

/* Status register bits */
#define UART_STAT_RXDV  (1u << 0)   /* RX FIFO has valid data      */
#define UART_STAT_RXFF  (1u << 1)   /* RX FIFO full                */
#define UART_STAT_TXFE  (1u << 2)   /* TX FIFO empty               */
#define UART_STAT_TXFF  (1u << 3)   /* TX FIFO full                */

/* Control register bits */
#define UART_CTRL_RSTTX (1u << 1)   /* reset TX FIFO               */
#define UART_CTRL_RSTRX (1u << 0)   /* reset RX FIFO               */

void    uart_init(void);
void    uart_putc(char c);
void    uart_puts(const char *s);
int     uart_getc(void);        /* blocking receive */

#endif /* UART_H */
