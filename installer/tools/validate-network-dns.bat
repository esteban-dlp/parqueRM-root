@echo off
setlocal
set INSTALL_DIR=C:\ParqueRM

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\validate-network-dns.ps1" -InstallDir "%INSTALL_DIR%" -OpenGuideOnWarning
set RESULT=%ERRORLEVEL%
echo.
if not "%RESULT%"=="0" (
    echo [ERROR] El DNS local no paso todas las pruebas.
    echo Revise C:\ParqueRM\logs\network y ejecute Diagnostico ParqueRM.
)
pause
exit /b %RESULT%

