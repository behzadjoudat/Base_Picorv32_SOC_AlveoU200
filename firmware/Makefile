# Firmware Makefile — RV64IMAC bare-metal for BOOM
#
# Requires a RISC-V GCC cross-compiler.  Probe for common prefixes:
#   riscv64-unknown-elf-gcc   (multi-arch distro build, preferred)
#   riscv32-unknown-elf-gcc   (will work if it supports -march=rv64)
#   riscv-none-embed-gcc      (xPack / ARM-style)
#
# Override on the command line: make CROSS=riscv64-unknown-elf-

CROSS    ?= $(shell \
    for p in riscv64-unknown-elf riscv32-unknown-elf riscv-none-embed; do \
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

# -march=rv64imac   — RV64 base + M/A/C extensions (BOOM's ISA)
# -mabi=lp64        — 64-bit integer ABI, no floating-point registers
# -mcmodel=medany   — PC-relative addressing (auipc+addi); required because
#   the default medlow model uses lui+addi which sign-extends to 64 bits and
#   cannot reach absolute addresses at 0x80000000 on RV64.
ARCH_FLAGS = -march=rv64imac -mabi=lp64 -mcmodel=medany

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

HDRS = $(wildcard *.h)

%.o: %.S $(HDRS)
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c $(HDRS)
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
