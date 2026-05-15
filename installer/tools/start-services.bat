@echo off
echo Starting ParqueRM services...
net start ParqueRMBackend
net start ParqueRMFrontend
echo Done.
pause
