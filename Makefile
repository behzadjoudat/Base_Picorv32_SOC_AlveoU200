# =============================================================================
# Top-level Makefile — BOOM SoC on Alveo U200
# =============================================================================
#
# Targets:
#   make gen_boom    — clone Chipyard, elaborate BOOM, copy Verilog to rtl/boom_gen/
#   make firmware    — build firmware.elf/.bin/.coe  (RV64IMAC)
#   make project     — create Vivado project + IPs
#   make bitstream   — synthesise → implement → write bitstream
#   make all         — gen_boom + firmware + project + bitstream
#   make program     — program the connected Alveo via hw_server
#   make monitor     — read UART output (stty + tail -f, if02-port0)
#   make clean       — remove firmware build artefacts
#   make cleanall    — also remove the Vivado project, bitstream, and boom_gen
#
# Prerequisites:
#   - Java 11+, sbt  (for gen_boom — Chipyard Chisel elaboration)
#   - riscv64-unknown-elf-gcc in PATH  (or override CROSS= in firmware/Makefile)
#   - Vivado 2022.1+ in PATH  (or set VIVADO= below)
#   - Python 3.6+
#
# Alter these variables for your environment:
VIVADO   ?= /tools/Xilinx/Vivado/2024.1/bin/vivado
PYTHON   ?= python3
PART     ?= xcu200-fsgd2104-2-e

# Add known toolchain locations to PATH so firmware/Makefile can find them
export PATH := /home/riscvnelib/bin:$(PATH)

.PHONY: all gen_boom firmware project bitstream program monitor clean cleanall

all: gen_boom firmware project bitstream

# ---- generate BOOM Verilog from Chipyard ------------------------------------
gen_boom:
	@echo "==> Generating BOOM Verilog (first run: 20-60 min) ..."
	@bash scripts/gen_boom.sh

# ---- firmware (RV64IMAC, links at 0x80000000) --------------------------------
firmware:
	@echo "==> Building firmware ..."
	$(MAKE) -C firmware

# ---- Vivado project ----------------------------------------------------------
project: firmware
	@echo "==> Creating Vivado project ..."
	$(VIVADO) -mode batch \
	    -source scripts/create_project.tcl \
	    -tclargs --part $(PART) \
	             --coe $(CURDIR)/firmware/firmware.coe \
	    -notrace 2>&1 | tee vivado_project.log

# ---- synthesis + implementation + bitstream ----------------------------------
bitstream: project
	@echo "==> Building bitstream (this takes 10–30 min) ..."
	$(VIVADO) -mode batch \
	    -source scripts/build.tcl \
	    -notrace 2>&1 | tee vivado_build.log
	@echo "==> Bitstream: alveo_boom_soc.bit"

# ---- program device ----------------------------------------------------------
program:
	@echo "==> Programming Alveo ..."
	$(VIVADO) -mode batch \
	    -source scripts/program.tcl \
	    -notrace 2>&1 | tee vivado_program.log

# ---- monitor UART ------------------------------------------------------------
# Uses stty + tail -f via /dev/serial/by-id (FT4232H interface 2).
# minicom's line discipline can swallow output; this avoids that.
monitor:
	@bash scripts/uart_monitor.sh

# ---- clean -------------------------------------------------------------------
clean:
	$(MAKE) -C firmware clean

cleanall: clean
	rm -rf vivado/ \
	       rtl/boom_gen/ \
	       vendor/ \
	       alveo_boom_soc.bit \
	       boom_gen.log \
	       vivado_project.log vivado_build.log vivado_program.log \
	       vivado.jou vivado.log .Xil
