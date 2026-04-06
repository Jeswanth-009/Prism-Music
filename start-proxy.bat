@echo off
echo Starting Prism Music Proxy Server...
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Node.js is not installed or not in PATH.
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Change to proxy server directory
cd /d "%~dp0proxy-server"

REM Install dependencies if node_modules doesn't exist
if not exist "node_modules" (
    echo Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo Error: Failed to install dependencies.
        pause
        exit /b 1
    )
    echo.
)

REM Start the server
echo Starting proxy server on port 3000...
echo Press Ctrl+C to stop the server
echo.
npm start