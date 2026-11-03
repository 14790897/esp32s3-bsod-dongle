#!/usr/bin/env bash
set -euo pipefail

PORT="${1:?usage: $0 <port> [firmware.bin]}"
BIN="${2:-firmware.bin}"

cat >&2 <<'MSG'
App-only flash at 0x10000 for the MicroPython/Boya layout.
Do NOT use merged.bin or bootloader.bin on that board.
Press Alt+F4 to exit the demo.
MSG

esptool --chip esp32s3 -p "$PORT" -b 460800 write_flash 0x10000 "$BIN"
