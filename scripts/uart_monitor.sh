#!/usr/bin/env bash
# uart_monitor.sh — read the Alveo U200 UART output
#
# The FT4232H on the Alveo U200 exposes 3 serial ports:
#   if01-port0  —  unknown / not the user UART
#   if02-port0  —  USB-UART bridge (this is our UART)
#   if03-port0  —  unknown
#
# minicom's line discipline buffers/transforms the byte stream; using
# stty(1) + tail -f avoids that and shows raw FPGA output immediately.

set -euo pipefail

GLOB='/dev/serial/by-id/usb-Xilinx_A-U200-P64G*-if02-port0'
DEVICE=$(ls $GLOB 2>/dev/null | head -1)

if [[ -z "$DEVICE" ]]; then
    echo "ERROR: Alveo U200 UART not found." >&2
    echo "       Expected: $GLOB" >&2
    echo "       Check USB-C cable and FT4232H driver (lsusb | grep Xilinx)." >&2
    exit 1
fi

echo ">> UART device : $DEVICE"
echo ">> Baud        : 115200 8N1"
echo ">> Press Ctrl-C to exit."
echo "------------------------------------------------------------"

stty -F "$DEVICE" 115200 nl raw cstopb -iexten -echo -echoe -echok -echoctl -echoke min 0
tail -f "$DEVICE"
