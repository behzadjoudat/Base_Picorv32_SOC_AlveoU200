/* start.S — RISC-V bare-metal startup for BOOM (RV64)
 * Reset vector is 0x80000000 (BRAM base on BOOM's MEM port).
 * Stack top is 0x80020000 (top of 128 KB BRAM).
 */

    .section .text.init, "ax", @progbits
    .globl  _start
    .type   _start, @function

_start:
    /* ---- set stack pointer ---- */
    li      sp, 0x80020000      /* top of 128 KB BRAM */

    /* ---- clear .bss (8-byte stores for RV64 alignment) ---- */
    la      t0, _bss_start
    la      t1, _bss_end
.bss_loop:
    bge     t0, t1, .bss_done
    sd      zero, 0(t0)
    addi    t0, t0, 8
    j       .bss_loop
.bss_done:

    /* ---- call main ---- */
    call    main

    /* ---- halt if main returns ---- */
.halt:
    j       .halt

    .size   _start, . - _start
