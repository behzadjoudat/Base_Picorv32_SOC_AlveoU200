#include "uart.h"

void uart_init(void)
{
    /* Set baud-rate divisor: f_clk / baud - 1 = 100000000 / 115200 - 1 = 867 */
    UART_DIV = UART_DIV_115200;
    /* Enable transmitter and receiver */
    UART_TXCTRL = UART_TXCTRL_TXEN;
    UART_RXCTRL = UART_RXCTRL_RXEN;
}

void uart_putc(char c)
{
    while (UART_TXDATA & UART_TXDATA_FULL)  /* spin while TX FIFO full */
        ;
    UART_TXDATA = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

int uart_getc(void)
{
    uint32_t rx;
    do { rx = UART_RXDATA; } while (rx & UART_RXDATA_EMPTY);
    return (int)(rx & 0xFF);
}
