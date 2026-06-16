# Firmware Makefile — RV32IM bare-metal for picorv32
#
# Requires a RISC-V GCC cross-compiler.  Probe for common prefixes:
#   riscv32-unknown-elf-gcc   (SiFive/Crosstool-NG, 32-bit only build)
#   riscv64-unknown-elf-gcc   (multi-arch distro build)
#   riscv-none-embed-gcc      (xPack / ARM-style)
#
# Override on the command line: make CROSS=riscv64-unknown-elf-

CROSS    ?= $(shell \
    for p in riscv32-unknown-elf riscv64-unknown-elf riscv-none-embed; do \
        command -v $${p}-gcc >/dev/null 2>&1 && echo "$$p-" && break; \
    done)

ifeq ($(CROSS),)
$(error No RISC-V cross-compiler found. Install one and set CROSS=<prefix>-)
endif

CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump
SIZE    = $(CROSS)size
PYTHON  ?= python3

# -march=rv32im  — RV32 base integer + M (multiply/divide)
# -mabi=ilp32    — 32-bit integer ABI, no floating-point registers
ARCH_FLAGS = -march=rv32im -mabi=ilp32

CFLAGS  = $(ARCH_FLAGS) \
          -Os -Wall -Wextra \
          -ffreestanding -fno-builtin \
          -ffunction-sections -fdata-sections \
          -nostartfiles

LDFLAGS = -T link.ld \
          -Wl,--gc-sections \
          -Wl,-Map=firmware.map \
          -lgcc

SRCS    = start.S uart.c syscalls.c main.c
OBJS    = $(patsubst %.S,%.o,$(patsubst %.c,%.o,$(SRCS)))

.PHONY: all clean

all: firmware.elf firmware.bin firmware.hex firmware.coe firmware.lst
	@$(SIZE) firmware.elf

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

firmware.elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

# 32-bit word hex for $readmemh (if ever used in simulation)
firmware.hex: firmware.bin
	$(PYTHON) ../scripts/bin2hex.py $< $@

# Xilinx .coe init file for Block Memory Generator
firmware.coe: firmware.bin
	$(PYTHON) ../scripts/bin2coe.py $< $@

firmware.lst: firmware.elf
	$(OBJDUMP) -d -S $< > $@

clean:
	rm -f $(OBJS) firmware.elf firmware.bin firmware.hex firmware.coe \
	      firmware.lst firmware.map
