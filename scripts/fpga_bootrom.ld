/* linker script for fpga_bootrom.S — places code at 0x10000 (AbstractConfig BootROM base) */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS {
    . = 0x10000;
    .text.start : { *(.text.start) *(.text*) }
    /DISCARD/ : { *(*) }
}
