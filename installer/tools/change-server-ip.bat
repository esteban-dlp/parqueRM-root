@echo off
setlocal enabledelayedexpansion

net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set INSTALL_DIR=C:\ParqueRM

echo ParqueRM - Change Server IP
echo ============================
echo This updates all config files with a new server IP address.
echo Run this if the server's IP address has changed.
echo.

:: Show detected IPs
echo Detected network addresses:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\get-local-ip.ps1" 2>nul
echo.

set /p NEW_IP=Enter new server IP address:
if "%NEW_IP%"=="" (
    echo [ERROR] IP address cannot be empty.
    pause & exit /b 1
)

set /p DB_PASS=Enter SQL Server SA password:
if "%DB_PASS%"=="" (
    echo [ERROR] Password cannot be empty.
    pause & exit /b 1
)

echo.
echo Updating configuration for IP: %NEW_IP%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\generate-config.ps1" ^
    -InstallDir "%INSTALL_DIR%" ^
    -ServerIp "%NEW_IP%" ^
    -DbPassword "%DB_PASS%" ^
    -PreserveExistingSecrets

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Configuration update failed.
    pause & exit /b 1
)

echo.
echo Restarting services to apply new configuration...
net stop ParqueRMFrontend >nul 2>&1
net stop ParqueRMBackend  >nul 2>&1
timeout /t 3 /nobreak >nul
net start ParqueRMBackend  >nul 2>&1
net start ParqueRMFrontend >nul 2>&1

echo [OK] Services restarted.
echo.
echo Other computers on the LAN can now access ParqueRM at:
echo   http://%NEW_IP%
echo.
pause
