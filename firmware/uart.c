#include "uart.h"

void uart_init(void)
{
    /* Reset both FIFOs, then clear control register */
    UART_CTRL = UART_CTRL_RSTTX | UART_CTRL_RSTRX;
    UART_CTRL = 0;
}

void uart_putc(char c)
{
    while (UART_STAT & UART_STAT_TXFF)  /* spin while TX FIFO full */
        ;
    UART_TX = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

int uart_getc(void)
{
    while (!(UART_STAT & UART_STAT_RXDV))  /* spin until data available */
        ;
    return (int)(UART_RX & 0xFF);
}
