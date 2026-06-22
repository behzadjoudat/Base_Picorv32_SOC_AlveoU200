#include "uart.h"

int main(void)
{
    uart_init();
    uart_puts("Hello, World!\r\n");
    uart_puts("BOOM SoC running on Alveo U200\r\n");

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
