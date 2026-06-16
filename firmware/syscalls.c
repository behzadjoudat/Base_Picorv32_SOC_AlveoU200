/* Minimal newlib stubs so printf/puts link against our UART. */
#include <sys/stat.h>
#include <errno.h>
#include "uart.h"

int _write(int file, char *ptr, int len)
{
    (void)file;
    for (int i = 0; i < len; i++)
        uart_putc(ptr[i]);
    return len;
}

int _read(int file, char *ptr, int len)
{
    (void)file;
    if (len == 0) return 0;
    *ptr = (char)uart_getc();
    return 1;
}

void _exit(int status)
{
    (void)status;
    while (1);
}

int _close(int file)  { (void)file; return -1; }
int _isatty(int file) { (void)file; return 1;  }
int _lseek(int file, int ptr, int dir) { (void)file; (void)ptr; (void)dir; return 0; }

int _fstat(int file, struct stat *st)
{
    (void)file;
    st->st_mode = S_IFCHR;
    return 0;
}

void *_sbrk(int incr)
{
    extern char _end;           /* defined by linker script */
    static char *heap = 0;
    if (!heap) heap = &_end;
    char *prev = heap;
    heap += incr;
    return (void *)prev;
}
