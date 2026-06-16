#include "uart.h"

int main(void)
{
    uart_init();
    uart_puts("Hello, World!\r\n");
    uart_puts("PicoRV32 SoC running on Alveo\r\n");

    /* Echo loop — type characters and see them reflected back */
    uart_puts("Echo mode (type to test RX):\r\n");
    while (1) {
        int c = uart_getc();
        uart_putc((char)c);
        if (c == '\r')
            uart_putc('\n');
    }

    return 0;
}
