@echo off
echo Stopping ParqueRM services...
net stop ParqueRMFrontend
net stop ParqueRMBackend
echo Done.
pause
