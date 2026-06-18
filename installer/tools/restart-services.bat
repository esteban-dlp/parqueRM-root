@echo off
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Restarting ParqueRM services...
net stop ParqueRMLocalName
net stop ParqueRMFrontend
net stop ParqueRMBackend
sc query ParqueRMDns >nul 2>&1 && net stop ParqueRMDns >nul 2>&1
timeout /t 3 /nobreak >nul
net start ParqueRMBackend
net start ParqueRMFrontend
net start ParqueRMLocalName
sc query ParqueRMDns >nul 2>&1 && net start ParqueRMDns >nul 2>&1
echo Done.
pause
