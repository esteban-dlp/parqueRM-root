@echo off
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Starting ParqueRM services...
net start ParqueRMBackend
net start ParqueRMFrontend
net start ParqueRMLocalName
echo Done.
pause
