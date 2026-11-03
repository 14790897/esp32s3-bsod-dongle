@echo off
set PORT=%1
if "%PORT%"=="" set PORT=COM3
set BIN=%2
if "%BIN%"=="" set BIN=firmware.bin
echo App-only flash at 0x10000 for the MicroPython/Boya layout.
echo Do NOT use merged.bin or bootloader.bin on that board.
esptool --chip esp32s3 -p %PORT% -b 460800 write_flash 0x10000 %BIN%
