OUTPUT_ARCH(riscv)
ENTRY(_start)

/*
 * Memory map
 *   BRAM  0x80000000 – 0x8001FFFF  (128 KB, BOOM MEM port)
 *
 * Stack grows DOWN from the top of BRAM.
 * Heap grows UP from _end.
 */
MEMORY {
    bram (rwx) : ORIGIN = 0x80000000, LENGTH = 128K
}

SECTIONS {
    .text : {
        KEEP(*(.text.init))   /* startup code must be first */
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(8);
    } > bram

    .data : {
        . = ALIGN(8);
        *(.data .data.*)
        . = ALIGN(8);
    } > bram

    .bss : {
        . = ALIGN(8);
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    } > bram

    /* Heap starts here; _sbrk() grows it upward */
    _end = .;

    /DISCARD/ : {
        *(.eh_frame)
        *(.ARM.exidx)
    }
}
