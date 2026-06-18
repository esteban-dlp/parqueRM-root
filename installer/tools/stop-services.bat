@echo off
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Stopping ParqueRM services...
net stop ParqueRMLocalName
net stop ParqueRMFrontend
net stop ParqueRMBackend
sc query ParqueRMDns >nul 2>&1 && net stop ParqueRMDns >nul 2>&1
echo Done.
pause
