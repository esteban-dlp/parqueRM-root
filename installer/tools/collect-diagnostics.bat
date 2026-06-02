@echo off
setlocal

set INSTALL_DIR=C:\ParqueRM

echo Collecting ParqueRM diagnostics...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\collect-diagnostics.ps1" -InstallDir "%INSTALL_DIR%"
echo.
pause
