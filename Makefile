# =============================================================================
# Top-level Makefile — PicoRV32 SoC on Alveo U200
# =============================================================================
#
# Targets:
#   make deps        — download picorv32.v (needs curl + internet)
#   make firmware    — build firmware.elf/.bin/.coe
#   make project     — create Vivado project + IPs
#   make bitstream   — synthesise → implement → write bitstream
#   make all         — deps + firmware + project + bitstream
#   make program     — program the connected Alveo via hw_server
#   make monitor     — read UART output (stty + tail -f, if02-port0)
#   make clean       — remove firmware build artefacts
#   make cleanall    — also remove the Vivado project and bitstream
#
# Prerequisites:
#   - RISC-V GCC (riscv32-unknown-elf-gcc or riscv64-unknown-elf-gcc)
#   - Vivado 2022.1+ in PATH   (or set VIVADO= below)
#   - Python 3.6+
#
# Alter these variables for your environment:
VIVADO   ?= vivado
PYTHON   ?= python3
PART     ?= xcu200-fsgd2104-2-e

# Add known toolchain locations to PATH so firmware/Makefile can find them
export PATH := /home/sahand/riscv/bin:$(PATH)

.PHONY: all deps firmware project bitstream program monitor clean cleanall

all: deps firmware project bitstream

# ---- fetch PicoRV32 core from GitHub ----------------------------------------
deps:
	@echo "==> Fetching PicoRV32 ..."
	@bash scripts/fetch_picorv32.sh

# ---- firmware ---------------------------------------------------------------
firmware: deps
	@echo "==> Building firmware ..."
	$(MAKE) -C firmware

# ---- Vivado project (block design) ------------------------------------------
project: firmware
	@echo "==> Creating Vivado project ..."
	$(VIVADO) -mode batch \
	    -source scripts/create_project.tcl \
	    -tclargs --part $(PART) \
	             --coe $(CURDIR)/firmware/firmware.coe \
	    -notrace 2>&1 | tee vivado_project.log

# ---- synthesis + implementation + bitstream ---------------------------------
bitstream: project
	@echo "==> Building bitstream (this takes 10–30 min) ..."
	$(VIVADO) -mode batch \
	    -source scripts/build.tcl \
	    -notrace 2>&1 | tee vivado_build.log
	@echo "==> Bitstream: alveo_picorv32_soc.bit"

# ---- program device ---------------------------------------------------------
program:
	@echo "==> Programming Alveo ..."
	$(VIVADO) -mode batch \
	    -source scripts/program.tcl \
	    -notrace 2>&1 | tee vivado_program.log

# ---- monitor UART -----------------------------------------------------------
# Uses stty + tail -f via /dev/serial/by-id (FT4232H interface 2).
# minicom's line discipline can swallow output; this avoids that.
monitor:
	@bash scripts/uart_monitor.sh

# ---- clean ------------------------------------------------------------------
clean:
	$(MAKE) -C firmware clean

cleanall: clean
	rm -rf vivado/ \
	       alveo_picorv32_soc.bit \
	       vivado_project.log vivado_build.log vivado_program.log \
	       vivado.jou vivado.log .Xil
