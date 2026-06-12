@echo off
setlocal enabledelayedexpansion

net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set INSTALL_DIR=C:\ParqueRM

echo ParqueRM - Repair Local URL
echo ===========================
echo This refreshes the stable local URL:
echo   http://parque.rm.local
echo.

echo Refreshing local hostnames...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\configure-local-name.ps1" -InstallDir "%INSTALL_DIR%"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Local URL repair failed.
    pause & exit /b 1
)

echo.
echo Restarting local-name service...
net stop ParqueRMLocalName >nul 2>&1
timeout /t 3 /nobreak >nul
net start ParqueRMLocalName >nul 2>&1

echo [OK] Local URL refreshed.
echo.
echo Recommended URL:
echo   http://parque.rm.local
echo.
pause
