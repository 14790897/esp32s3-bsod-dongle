#!/usr/bin/env bash
set -euo pipefail

PORT="${1:?usage: $0 <port> [merged.bin]}"
BIN="${2:-merged.bin}"

cat >&2 <<'MSG'
Standard ESP32-S3 factory flash at 0x0 (merged image).
Do NOT use this on a Boya-flash board with a MicroPython bootloader.
Press Alt+F4 to exit the demo.
MSG

esptool --chip esp32s3 -p "$PORT" -b 460800 write_flash 0x0 "$BIN"
