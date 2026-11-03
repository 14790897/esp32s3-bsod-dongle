# Building and CI

## Toolchain

- ESP-IDF **v6.1** (the upstream GhostESP CI uses `v6.1`).
- A Linux/macOS/WSL host with `git`, Python 3, and `zip`.
- The build targets `esp32s3` with 4 MB flash and no PSRAM.

## Local build

```bash
git clone https://github.com/14790897/esp32s3-bsod-dongle.git
cd esp32s3-bsod-dongle
. ~/esp-idf/export.sh
export IDF_PATH=~/esp-idf
PAYLOAD_URL=https://your.example/page.html ./scripts/build.sh
```

`scripts/build.sh`:

1. Clones `GhostESP-Revival/GhostESP` at the pinned commit
   `4f4e1cfe97a37b69f8bc20a5f4b028c1b028aa0f` (or `GHOSTESP_COMMIT`).
2. Applies `patches/0001-badusb-autorun.patch`.
3. Copies `configs/sdkconfig.esp32s3-bsod` over `configs/sdkconfig.default.esp32s3`
   and substitutes `@PAYLOAD_URL@`.
4. Copies it to both `sdkconfig.defaults` and `sdkconfig`.
5. Runs `idf.py build`, checks the app partition fit, and packages
   `dist/firmware.bin`, `bootloader.bin`, `partitions.bin`, `merged.bin`,
   `build-info.json`, and `sha256sums.txt` into
   `esp32s3-bsod-dongle.zip`.

The app is `build/Ghost_ESP_IDF.bin`; the app offset is `0x10000` and the
partition table offset is `0x8000` for this 4 MB layout.

## Build config

`configs/sdkconfig.esp32s3-bsod` is the tracked generic ESP32-S3 config plus:

```text
CONFIG_HAS_BADUSB=y
CONFIG_TINYUSB_HID_COUNT=3
CONFIG_ESP_CONSOLE_SECONDARY_NONE=y
CONFIG_BADUSB_VSENSE_PIN=-1
CONFIG_BADUSB_AUTORUN=y
CONFIG_BADUSB_AUTORUN_COMMAND="msedge --kiosk @PAYLOAD_URL@"
```

The HID count must be 3 because BadUSB exposes keyboard, mouse, and consumer
interfaces. The USB Serial/JTAG secondary console is disabled so the native USB
belongs to TinyUSB HID; the FTDI/UART console remains available. The payload URL
is a build-time string, substituted by the script and CI.

## Patch

`patches/0001-badusb-autorun.patch` applies to the pinned upstream commit. It
adds:

- `CONFIG_BADUSB_AUTORUN` and `CONFIG_BADUSB_AUTORUN_COMMAND` in
  `main/Kconfig.projbuild`.
- `badusb_manager_autorun()` and its declaration.
- The boot-time call in `main/main.c`.

The function builds a DuckyScript with `DELAY`/`GUI r`/`STRING`/`ENTER` and uses
the existing `badusb_manager_execute_buffer()` executor. No new USB stack is
added.

## CI

`.github/workflows/build.yml` installs ESP-IDF v6.1 (cached), applies the
upstream gdbstub compatibility patch, runs `scripts/build.sh`, and uploads the
zip. A build runs on every push to `main`, on `v*` tags, and on manual dispatch.

`PAYLOAD_URL` can be set as a repository variable or supplied as a manual
dispatch input. The release job runs on a `v*` tag or a manual dispatch with
`release=true`, and publishes the zip with `gh release create`.

No secrets are required for a build. The release uses the workflow
`GITHUB_TOKEN` with `contents: write`.

## Updating the upstream pin

1. Change `GHOSTESP_COMMIT` in `scripts/build.sh` and
   `.github/workflows/build.yml`.
2. Refresh the patch if the upstream files changed:
   `git -C <ghostesp> diff` after applying the changes, or regenerate it from
   the four modified files.
3. Run the build and a flash test before publishing.

The `PAYLOAD_URL` string is compiled into the app. Changing it requires a new
build; changing the page content does not.
