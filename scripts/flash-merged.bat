@echo off
set PORT=%1
if "%PORT%"=="" set PORT=COM3
set BIN=%2
if "%BIN%"=="" set BIN=merged.bin
echo Standard ESP32-S3 factory flash at 0x0.
echo Do NOT use this on a Boya-flash board with a MicroPython bootloader.
esptool --chip esp32s3 -p %PORT% -b 460800 write_flash 0x0 %BIN%
