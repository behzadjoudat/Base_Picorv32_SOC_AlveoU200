/* fpga_bootrom.S — minimal BootROM for standalone FPGA deployment
 *
 * The testchipip default BootROM waits in WFI for the simulation TestHarness
 * to deliver a machine-software interrupt via SerialTL + CLINT.  On bare FPGA
 * that interrupt never comes, so the CPU sleeps forever.
 *
 * This replacement skips all that: hart 0 jumps directly to DRAM base.
 * Non-zero harts (none in SmallBOOM, but handled for correctness) spin.
 *
 * Must be linked at 0x10000 to match AbstractConfig's BootROM address.
 *
 * DRAM base = 0x80000000.  Loading it without sign-extension on RV64:
 *   li t0, 1 ; slli t0, t0, 31  →  t0 = 0x0000000080000000  (no sign ext)
 *
 * Registers on entry to firmware (Linux/OpenSBI convention):
 *   a0 = mhartid
 *   a1 = 0   (no DTB; our firmware ignores these)
 */
.section .text.start, "ax", @progbits
.global _start
_start:
    csrr   a0, mhartid       /* a0 = hart ID (also boot arg) */
    bnez   a0, _hang          /* non-primary harts spin       */
    li     a1, 0              /* a1 = DTB pointer (none)      */
    li     t0, 1
    slli   t0, t0, 31         /* t0 = 0x0000000080000000      */
    jr     t0                 /* jump to firmware             */

_hang:
    wfi
    j      _hang
