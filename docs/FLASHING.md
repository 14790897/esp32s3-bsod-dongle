# Flashing and recovery

## Before flashing

- Use the **native USB** port of the ESP32-S3 (the USB OTG / USB-Serial-JTAG port). The UART/FTDI header alone cannot do BadUSB HID.
- The firmware opens `msedge --kiosk <PAYLOAD_URL>`; Edge must be installed. The default hosted page needs internet access.
- The dongle types into the active Windows session on **every boot**. Do not leave it plugged into a machine where that is unwanted.
- Back up the current firmware first. For a 4 MB board:

  ```bash
  esptool --chip esp32s3 -p <port> read_flash 0x0 0x400000 backup-4mb.bin
  ```

  For a 16 MB board use `0x1000000` as the length. Keep the backup somewhere safe.

The release zip contains both layouts:

- `merged.bin` — standard ESP-IDF S3 factory image (bootloader at 0x0, partition table at 0x8000, app at 0x10000).
- `firmware.bin` — app-only image for a board that already has a working bootloader + partition table, such as the tested Boya/MicroPython layout.
- `bootloader.bin`, `partitions.bin` — the standard ESP-IDF pieces.

## Standard ESP32-S3

```bash
esptool --chip esp32s3 -p <port> -b 460800 write_flash 0x0 merged.bin
```

This overwrites the bootloader, partition table and app. It is the normal choice for a stock ESP32-S3 board with 4 MB flash.

## Boya flash + MicroPython S3 bootloader

The tested board uses this layout:

| Offset | Contents |
| --- | --- |
| `0x0` | MicroPython ESP32_GENERIC_S3 bootloader |
| `0x8000` | GhostESP partition table |
| `0x10000` | application |

Only replace the app:

```bash
esptool --chip esp32s3 -p <port> -b 460800 write_flash 0x10000 firmware.bin
```

**Do not** flash `merged.bin` or `bootloader.bin` on this layout. It overwrites the MicroPython bootloader at 0x0 and the board can boot-loop. This repository does not redistribute the MicroPython bootloader; if your Boya board does not already have it, use a standard S3 board.

The app-only image is built with the standard 4 MB partition table; the app partition is `0x10000` + `0x3E0000`.

## First boot

1. Plug the dongle into the target PC using the native USB port (and the UART/FTDI port only if you want the serial console).
2. The S3 waits about 4 seconds, presses `Win+R` twice, waits, types the `msedge --kiosk ...` command and presses Enter.
3. Edge opens the demo full-screen: fake terminal for about 8 seconds, then fake BSOD.
4. Press **Alt+F4** to exit. If Edge is stuck, open Task Manager and end the Edge process.

The sequence runs once per boot. Unplug the dongle to stop it from running at the next boot.

## Restore

- Standard S3: reflash your backup at 0x0, or reflash the official GhostESP S3 build.
- Boya/MicroPython: reflash only the previous app at 0x10000; do not touch 0x0/0x8000.
- The original GhostESP app backup used during development is not part of this repository. Keep your own backup.

## Troubleshooting

### The board boot-loops after flashing

If it prints `Factory app partition is not bootable` or `invalid segment length 0xffffffff`, the bootloader/partition table may be intact and only the app is bad. Reflash the app at 0x10000. On a Boya/MicroPython board never "fix" this by flashing the official bootloader or a full-chip image.

### Edge does not open

The payload uses `msedge`. If Edge is not installed, change the payload to `chrome --kiosk <url>` or `start <url>` and rebuild. On Windows, check that `msedge` resolves from the Run dialog.

### The page is blank

The default page is hosted on Vercel and requires internet access. Check the URL in `build-info.json`; use a local page or a different host if you need offline operation. Edge kiosk still needs a working network for a hosted URL.

### It types only once / the first run misses keys

HID enumeration on a cold boot can be slower than the first `Win+R`. The build intentionally sends `Win+R` twice and waits. Unplug/replug and try again; avoid having the PC locked or in a secure desktop when it boots.

### I need to exit the demo quickly

`Alt+F4` closes the kiosk. The on-page hint at 100% also says `Alt+F4`.
