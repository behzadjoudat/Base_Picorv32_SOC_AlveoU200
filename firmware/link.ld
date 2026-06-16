OUTPUT_ARCH(riscv)
ENTRY(_start)

/*
 * Memory map
 *   BRAM  0x00000000 – 0x0001FFFF  (128 KB)
 *
 * Stack grows DOWN from the top of BRAM.
 * Heap grows UP from _end.  They meet in the middle if both are ever used.
 */
MEMORY {
    bram (rwx) : ORIGIN = 0x00000000, LENGTH = 128K
}

SECTIONS {
    .text : {
        KEEP(*(.text.init))   /* startup code must be first */
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > bram

    .data : {
        . = ALIGN(4);
        *(.data .data.*)
        . = ALIGN(4);
    } > bram

    .bss : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > bram

    /* Heap starts here; _sbrk() grows it upward */
    _end = .;

    /* Discard C++ exception tables we don't handle */
    /DISCARD/ : {
        *(.eh_frame)
        *(.ARM.exidx)
    }
}
