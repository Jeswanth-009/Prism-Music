@echo off
echo ================================================
echo Prism Music - Find Development Machine IP
echo ================================================
echo.
echo Your computer's IPv4 addresses for device debugging:
ipconfig | findstr /i "IPv4"
echo.
echo ================================================
echo Device Debugging Tips:
echo ================================================
echo.
echo 1. Ensure your test device and computer are on the same Wi-Fi network.
echo 2. For wireless debugging with ADB:
echo    adb tcpip 5555
echo    adb connect ^<DEVICE_IP^>:5555
echo.
pause