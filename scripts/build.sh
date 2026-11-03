#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_URL="${PAYLOAD_URL:-https://ghost-esp-demo.vercel.app/}"
GHOSTESP_REPO="${GHOSTESP_REPO:-https://github.com/GhostESP-Revival/GhostESP.git}"
GHOSTESP_COMMIT="${GHOSTESP_COMMIT:-4f4e1cfe97a37b69f8bc20a5f4b028c1b028aa0f}"
WORK="${WORK:-$ROOT/.work}"
DIST="$ROOT/dist"
ZIP="$ROOT/esp32s3-bsod-dongle.zip"

if [[ -z "${IDF_PATH:-}" ]]; then
  echo "IDF_PATH is not set. Install ESP-IDF v6.1 and source export.sh first." >&2
  exit 1
fi
if [[ ! -f "$IDF_PATH/export.sh" ]]; then
  echo "IDF_PATH does not look like ESP-IDF: $IDF_PATH" >&2
  exit 1
fi

rm -rf "$WORK" "$DIST" "$ZIP"
mkdir -p "$WORK/ghostesp" "$DIST"

echo "Fetching GhostESP $GHOSTESP_COMMIT"
git -C "$WORK/ghostesp" init -q
git -C "$WORK/ghostesp" remote add origin "$GHOSTESP_REPO"
git -C "$WORK/ghostesp" fetch --depth 1 origin "$GHOSTESP_COMMIT"
git -C "$WORK/ghostesp" checkout -q FETCH_HEAD

echo "Applying autorun patch"
git -C "$WORK/ghostesp" apply "$ROOT/patches/0001-badusb-autorun.patch"

echo "Configuring ESP32-S3 BadUSB autorun build"
CFG="$WORK/ghostesp/configs/sdkconfig.default.esp32s3"
cp "$ROOT/configs/sdkconfig.esp32s3-bsod" "$CFG"
python3 - "$CFG" "$PAYLOAD_URL" <<'PY'
import sys

path, url = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
if "@PAYLOAD_URL@" not in text:
    raise SystemExit("config placeholder @PAYLOAD_URL@ not found")
text = text.replace("@PAYLOAD_URL@", url)
open(path, "w", encoding="utf-8", newline="\n").write(text)
PY
cp "$CFG" "$WORK/ghostesp/sdkconfig.defaults"
cp "$CFG" "$WORK/ghostesp/sdkconfig"

. "$IDF_PATH/export.sh"
export IDF_TARGET=esp32s3
export SDKCONFIG_DEFAULTS=sdkconfig.defaults
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc 2>/dev/null || echo 2)}"

cd "$WORK/ghostesp"
idf.py build

echo "Checking app partition fit"
python3 scripts/partition_table.py check-fit \
  build/Ghost_ESP_IDF.bin build/partition_table/partition-table.bin

COMMIT="$(git rev-parse HEAD)"
IDF_VERSION="$(git -C "$IDF_PATH" describe --tags --always 2>/dev/null || echo unknown)"

python3 - "$DIST/build-info.json" "$PAYLOAD_URL" "$COMMIT" "$IDF_VERSION" <<'PY'
import datetime
import json
import sys

path, url, commit, idf_version = sys.argv[1:5]
data = {
    "payload_url": url,
    "ghostesp_commit": commit,
    "idf_version": idf_version,
    "idf_target": "esp32s3",
    "app_offset": "0x10000",
    "built_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
with open(path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

cp build/Ghost_ESP_IDF.bin "$DIST/firmware.bin"
cp build/bootloader/bootloader.bin "$DIST/bootloader.bin"
cp build/partition_table/partition-table.bin "$DIST/partitions.bin"
python3 -m esptool --chip esp32s3 merge_bin \
  --output "$DIST/merged.bin" \
  --flash_mode dio --flash_freq 80m --flash_size 4MB \
  --target-offset 0x0 \
  0x0 "$DIST/bootloader.bin" \
  0x8000 "$DIST/partitions.bin" \
  0x10000 "$DIST/firmware.bin"

cd "$DIST"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum firmware.bin bootloader.bin partitions.bin merged.bin build-info.json > sha256sums.txt
else
  shasum -a 256 firmware.bin bootloader.bin partitions.bin merged.bin build-info.json > sha256sums.txt
fi
zip -j "$ZIP" firmware.bin bootloader.bin partitions.bin merged.bin build-info.json sha256sums.txt

echo "Built $ZIP"
ls -lh "$ZIP" "$DIST"
