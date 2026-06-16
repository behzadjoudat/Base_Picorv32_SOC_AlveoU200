/* start.S — RISC-V bare-metal startup for picorv32
 * Reset vector is 0x00000000 (PROGADDR_RESET).
 * Stack top is 0x00020000 (STACKADDR parameter, but we also set it here
 * explicitly so the firmware works even if the parameter is wrong).
 */

    .section .text.init, "ax", @progbits
    .globl  _start
    .type   _start, @function

_start:
    /* ---- set stack pointer ---- */
    li      sp, 0x00020000      /* top of 128 KB BRAM */

    /* ---- clear .bss ---- */
    la      t0, _bss_start
    la      t1, _bss_end
.bss_loop:
    bge     t0, t1, .bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .bss_loop
.bss_done:

    /* ---- call main ---- */
    call    main

    /* ---- halt if main returns ---- */
.halt:
    j       .halt

    .size   _start, . - _start
