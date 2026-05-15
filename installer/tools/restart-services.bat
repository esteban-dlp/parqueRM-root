@echo off
echo Restarting ParqueRM services...
net stop ParqueRMFrontend
net stop ParqueRMBackend
timeout /t 3 /nobreak >nul
net start ParqueRMBackend
net start ParqueRMFrontend
echo Done.
pause
