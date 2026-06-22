#!/usr/bin/env bash
# gen_boom.sh -- Clone Chipyard, install the custom config, generate BOOM Verilog.
#
# Prerequisites on the host:
#   java 11+  (present: OpenJDK 21)
#   git, curl, make, python3
#
# sbt and CIRCT/firtool are installed locally under vendor/ -- nothing system-wide.
#
# Runtime: first run 30-90 min; subsequent runs skip bootstrap (via .init-done).
# Output:  rtl/boom_gen/  (ChipTop.v + all Chipyard-generated support files)

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor"
BIN="$VENDOR/bin"
OUT="$REPO_ROOT/rtl/boom_gen"

# ---- 0. Select Java 11 or 17 (Scala 2.12 breaks on Java 21) -----------------
# Chipyard uses Scala 2.12.17 which has a known classfile-parser bug on Java 21.
# Prefer Java 17, fall back to Java 11.  Java 21 will NOT work.
for JDIR in \
    /usr/lib/jvm/java-17-openjdk-amd64 \
    /usr/lib/jvm/java-17-openjdk \
    /usr/lib/jvm/temurin-17 \
    /usr/lib/jvm/java-11-openjdk-amd64 \
    /usr/lib/jvm/java-11-openjdk \
    /usr/lib/jvm/temurin-11 ; do
    if [ -x "$JDIR/bin/java" ]; then
        export JAVA_HOME="$JDIR"
        export PATH="$JAVA_HOME/bin:$PATH"
        break
    fi
done

if ! command -v java >/dev/null 2>&1; then
    echo "ERROR: No Java found."
    echo "       Install Java 17: sudo apt install openjdk-17-jdk"
    exit 1
fi
JAVA_VER=$(java -version 2>&1 | awk -F'"' '/version/{print $2}' | cut -d. -f1)
if [ "$JAVA_VER" -ge 21 ]; then
    echo "ERROR: Scala 2.12.17 (used by Chipyard) is incompatible with Java $JAVA_VER."
    echo "       Install Java 17: sudo apt install openjdk-17-jdk"
    echo "       Then re-run: make gen_boom"
    exit 1
fi
if [ "$JAVA_VER" -lt 11 ]; then
    echo "ERROR: Java 11-20 required (found Java $JAVA_VER)."
    exit 1
fi
echo ">> Java $JAVA_VER detected at ${JAVA_HOME:-system}."

# ---- 1. Install sbt via coursier (local, no sudo) ----------------------------
mkdir -p "$BIN"
if ! command -v sbt >/dev/null 2>&1 && [ ! -x "$BIN/sbt" ]; then
    echo ">> sbt not found -- installing via coursier into $BIN ..."
    CS_TMP="$BIN/cs-installer"
    curl -fL "https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz" \
        | gzip -d > "$CS_TMP"
    chmod +x "$CS_TMP"
    "$CS_TMP" install sbt --install-dir "$BIN" --quiet
    rm -f "$CS_TMP"
    echo ">> sbt installed at $BIN/sbt"
fi
export PATH="$BIN:$PATH"

# ---- 2. Clone Chipyard (shallow) ---------------------------------------------
if [ ! -d "$VENDOR/chipyard" ]; then
    echo ">> Cloning Chipyard (shallow) ..."
    git clone --depth 1 https://github.com/ucb-bar/chipyard "$VENDOR/chipyard"
fi
cd "$VENDOR/chipyard"

# ---- 3. Bootstrap: submodules + CIRCT (first time only) ----------------------
# build-setup.sh requires $RISCV when --skip-conda is used.
# Point it at the existing RISC-V toolchain; firtool will be installed there.
export RISCV="${RISCV:-/home/riscvnelib}"
echo ">> Using RISCV=$RISCV"

if [ ! -f .init-done ]; then
    echo ">> Initialising submodules and downloading CIRCT/firtool ..."
    ./build-setup.sh \
        --skip-conda \
        --skip-toolchain \
        --skip-ctags \
        --skip-precompile \
        --skip-firesim \
        --skip-marshal \
        --skip-clean
    touch .init-done
fi

# ---- 4. Put CIRCT/firtool on PATH --------------------------------------------
# build-setup.sh installs firtool into $RISCV/bin when --skip-conda is used.
if [ -x "$RISCV/bin/firtool" ]; then
    echo ">> firtool found at $RISCV/bin/firtool"
    export PATH="$RISCV/bin:$PATH"
else
    FIRTOOL=$(find "$PWD" -name firtool -type f 2>/dev/null | head -1 || true)
    if [ -n "$FIRTOOL" ]; then
        echo ">> firtool found at $FIRTOOL"
        export PATH="$(dirname "$FIRTOOL"):$PATH"
    else
        echo "WARNING: firtool not found -- elaboration may fail."
    fi
fi

# ---- 5. Install our custom Chisel config -------------------------------------
echo ">> Installing AlveoSmallBoomConfig ..."
cp "$REPO_ROOT/scripts/AlveoSmallBoomConfig.scala" \
   generators/chipyard/src/main/scala/config/AlveoSmallBoomConfig.scala

# ---- 6. Elaborate -> generate Verilog ----------------------------------------
echo ">> Elaborating AlveoSmallBoomConfig -> Verilog (first time: 20-40 min) ..."
cd sims/verilator
make CONFIG=AlveoSmallBoomConfig verilog 2>&1 | tee "$REPO_ROOT/boom_gen.log"

# ---- 7. Copy generated SystemVerilog to rtl/boom_gen/ ------------------------
# Chipyard/CIRCT outputs .sv (SystemVerilog) files into gen-collateral/.
# The top-level output directory is:
#   sims/verilator/generated-src/chipyard.harness.TestHarness.<CONFIG>/
# All synthesisable RTL lives in the gen-collateral/ subdirectory.
mkdir -p "$OUT"
CONFIG_NAME="chipyard.harness.TestHarness.AlveoSmallBoomConfig"
VDIR="$VENDOR/chipyard/sims/verilator/generated-src/$CONFIG_NAME"
GDIR="$VDIR/gen-collateral"

if [ ! -d "$GDIR" ]; then
    echo "ERROR: gen-collateral/ not found at $GDIR"
    echo "       Check $REPO_ROOT/boom_gen.log for elaboration errors."
    exit 1
fi

# Copy all .sv and .v files (gen-collateral is the firtool output dir)
cp "$GDIR"/*.sv "$OUT/" 2>/dev/null || true
cp "$GDIR"/*.v  "$OUT/" 2>/dev/null || true

# Also copy the filelist so Vivado can see the full file set
cp "$VDIR/$CONFIG_NAME.top.f"     "$OUT/" 2>/dev/null || true
cp "$VDIR/$CONFIG_NAME.all.f"     "$OUT/" 2>/dev/null || true
cp "$VDIR/$CONFIG_NAME.model.f"   "$OUT/" 2>/dev/null || true

echo ""
echo "================================================================"
echo " Generated SystemVerilog in: $OUT/"
echo " Top module: ChipTop  (ChipTop.sv)"
echo ""
echo " Port names already wired in rtl/boom_axi_wrap.v."
echo " If elaborating a different config, re-verify with:"
echo "   grep '^module ChipTop' $OUT/ChipTop.sv"
echo "   grep 'axi4_mem_0\|uart_0\|jtag\|serial_tl' $OUT/ChipTop.sv | head -30"
echo "================================================================"
