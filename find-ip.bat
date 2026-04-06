@echo off
echo ================================================
echo Prism Music - Find Your Development Machine IP
echo ================================================
echo.
echo Your computer's IP addresses:
ipconfig | findstr /i "IPv4"
echo.
echo ================================================
echo Android Setup Instructions:
echo ================================================
echo.
echo 1. Start the proxy server (keep this running):
echo    cd "C:\Prism Music\proxy-server"
echo    npm start
echo.
echo 2. For Android EMULATOR testing:
echo    - No changes needed, uses 10.0.2.2:3000 automatically
echo.
echo 3. For Android PHYSICAL DEVICE testing:
echo    - Copy one of the IPv4 addresses above
echo    - Edit: lib/data/datasources/remote/proxy/proxy_config.dart  
echo    - Replace '192.168.1.100' with your actual IP address
echo    - Make sure your phone and computer are on same WiFi
echo.
echo 4. Test the connection:
echo    - Open http://YOUR_IP_ADDRESS:3000/health in phone browser
echo    - Should show: {"status":"ok","service":"prism-music-proxy"}
echo.
pause