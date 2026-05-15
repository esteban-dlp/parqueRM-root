@echo off
setlocal

set INSTALL_DIR=C:\ParqueRM
set CONFIG=%INSTALL_DIR%\config\parquerm.config.json

:: Read frontend URL from config and open in default browser
for /f "usebackq delims=" %%u in (`powershell.exe -NoProfile -Command "try { $c = Get-Content '%CONFIG%' -Raw | ConvertFrom-Json; $c.frontendUrl } catch { 'http://localhost' }"`) do set FRONTEND_URL=%%u

echo Opening ParqueRM: %FRONTEND_URL%
start "" "%FRONTEND_URL%"

:: Also show status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\show-final-url.ps1" -InstallDir "%INSTALL_DIR%"
