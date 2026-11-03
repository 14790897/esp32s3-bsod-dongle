# ESP32-S3 BSOD Dongle

An ESP32-S3 BadUSB demo dongle that opens a full-screen fake hacker terminal / fake Windows BSOD page on boot. Based on [GhostESP](https://github.com/GhostESP-Revival/GhostESP), rebuilt as a small patch + config + CI release.

**Unofficial demo. Not affiliated with or endorsed by GhostESP.** For your own devices or devices you have written permission to test. The firmware types into the active desktop session and opens a browser page; it does not modify the system, but it can interrupt your work. Unplug it when you are not demoing.

## What it does

- On every boot with the native USB port connected, the S3 waits, opens the Windows Run dialog twice, and types:

  ```text
  msedge --kiosk <PAYLOAD_URL>
  ```

- Edge opens the demo page full-screen: about 8 seconds of a fake hacker terminal, then a fake Windows 11 BSOD. Press **Alt+F4** to leave.
- The default demo page is <https://hack.sixiangjia.de/>. It is a visual simulation, not a real crash. It needs internet access; Edge must be installed.
- It runs on every power-up. Keep the dongle unplugged when you are not using it.

## Download

Download the latest `esp32s3-bsod-dongle.zip` from [Releases](https://github.com/14790897/esp32s3-bsod-dongle/releases). It contains:

| File | Purpose |
| --- | --- |
| `firmware.bin` | App-only image, flash at `0x10000` (Boya/MicroPython layout) |
| `bootloader.bin` | Standard ESP-IDF S3 bootloader |
| `partitions.bin` | Standard ESP-IDF S3 partition table |
| `merged.bin` | Standard S3 factory image, flash at `0x0` |
| `build-info.json` | Payload URL, upstream commit, IDF version |
| `sha256sums.txt` | SHA-256 checksums |

Check the checksums before flashing:

```bash
sha256sum -c sha256sums.txt
```

## Flash

Use the **native USB** port (USB OTG / USB-Serial-JTAG port), not only the UART/FTDI header. Back up your current firmware first; see [docs/FLASHING.md](docs/FLASHING.md).

### Standard ESP32-S3 (4 MB flash, ESP-IDF layout)

```bash
esptool --chip esp32s3 -p <port> -b 460800 write_flash 0x0 merged.bin
```

On Windows use e.g. `-p COM5`; on Linux/macOS use `/dev/ttyACM0` or `/dev/cu.usbmodem*`.

### Boya flash + MicroPython S3 bootloader (the tested board)

This board boots from a MicroPython ESP32_GENERIC_S3 bootloader at `0x0`, with the GhostESP partition table at `0x8000` and the app at `0x10000`. The official IDF bootloader can boot-loop on this Boya flash, so **do not** flash `merged.bin` or `bootloader.bin` here.

```bash
esptool --chip esp32s3 -p <port> -b 460800 write_flash 0x10000 firmware.bin
```

The MicroPython bootloader is not redistributed by this repository. If your board does not already boot from that layout, use a standard ESP32-S3 board instead.

The app-only image is also what the CI tests; the merged image is the standard-layout variant.

## Build locally

Requirements: ESP-IDF **v6.1**, git, Python 3, `zip`, and a Linux/macOS/WSL host.

```bash
git clone https://github.com/14790897/esp32s3-bsod-dongle.git
cd esp32s3-bsod-dongle
. ~/esp-idf/export.sh
export IDF_PATH=~/esp-idf
PAYLOAD_URL=https://your.example/page.html ./scripts/build.sh
```

The script clones GhostESP at the pinned upstream commit, applies `patches/0001-badusb-autorun.patch`, copies `configs/sdkconfig.esp32s3-bsod`, substitutes the payload URL, builds the ESP32-S3 app, checks the 4 MB partition fit, and writes `esp32s3-bsod-dongle.zip` plus `dist/`.

`PAYLOAD_URL` defaults to the demo page. Any URL or command that follows `msedge --kiosk ` works; keep it short and quote-free.

## CI and releases

The GitHub Actions workflow builds on every push to `main`, on `v*` tags, and on manual dispatch. A tag (or a manual run with `release=true`) publishes a GitHub Release with the zip.

- `PAYLOAD_URL` can be set as a repository variable (Settings → Variables → Actions) or supplied as a manual-dispatch input.
- The default payload is `https://hack.sixiangjia.de/`. Set `PAYLOAD_URL` to another URL if you self-host the page.
- The build uses ESP-IDF v6.1 and the same `scripts/build.sh` as local builds.

## Change the payload

The firmware types a single `msedge --kiosk <PAYLOAD_URL>` command. To change it:

1. Set the `PAYLOAD_URL` repository variable or workflow input, or edit the default in `.github/workflows/build.yml`.
2. Or change `CONFIG_BADUSB_AUTORUN_COMMAND` in `configs/sdkconfig.esp32s3-bsod` and rebuild.

The page itself is in [`web/index.html`](web/index.html). It is standalone HTML/CSS/JS with no external assets and uses TEST-NET-1 (`192.0.2.0/24`) addresses only. Deploy it anywhere, or use the default demo URL.

## How it works

The patch adds an opt-in `CONFIG_BADUSB_AUTORUN` and `CONFIG_BADUSB_AUTORUN_COMMAND` to GhostESP. At boot, after the settings and USB stack are initialized, `badusb_manager_autorun()` builds a small DuckyScript and starts the existing BadUSB executor. The sequence is:

```text
DELAY 3000
GUI r
DELAY 500
STRING msedge --kiosk <PAYLOAD_URL>
DELAY 200
ENTER
```

The 3-second delay gives Windows time to bind the HID keyboard; a single `Win+R` then opens the Run dialog and the command is typed about 0.5 s later. The config also raises `CONFIG_TINYUSB_HID_COUNT` to 3 (keyboard, mouse, consumer) and disables the USB Serial/JTAG secondary console so the native USB is available to TinyUSB HID.

## Safety and authorized use

- Use only on your own computers or with explicit written authorization. Do not use this on other people's machines.
- It is a prank/demo: it opens a web page, does not encrypt files, steal credentials, or modify the OS. It does auto-type into the active session and can interrupt typing or open a full-screen window.
- The page is clearly a simulation (the on-page hint says `BSOD DEMO` and `Alt+F4` exits). Do not present it as a real compromise.
- Auto-runs on every boot. Unplug the dongle when not in use, especially on a shared or work machine.
- The repository does not include vendor bootloaders, Wi-Fi credentials, MAC addresses, BSSIDs, or private IP addresses.

## License and attribution

- This repository is licensed under **GPL-3.0**; see [LICENSE](LICENSE).
- Based on GhostESP at upstream commit `4f4e1cfe97a37b69f8bc20a5f4b028c1b028aa0f`; the patch and build config are in this repository. See [NOTICE](NOTICE) for the source offer.
- “GhostESP” is a trademark of its owners. This project uses a neutral name, is unofficial, and is not endorsed by the GhostESP project.
- No vendor binaries are redistributed; the firmware is built from source in CI.

## Layout

```text
configs/sdkconfig.esp32s3-bsod   ESP32-S3 build config (BadUSB + autorun + 4 MB)
patches/0001-badusb-autorun.patch  GhostESP patch
scripts/build.sh                 Reproducible local/CI build
scripts/flash-*.sh|bat           App-only and merged-image flash helpers
web/index.html                   Redacted standalone demo page
docs/FLASHING.md                 Backup, flash and restore details
docs/BUILDING.md                 Build/CI details
.github/workflows/build.yml      CI and release workflow
```
