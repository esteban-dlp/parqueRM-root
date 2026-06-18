@echo off
setlocal
set INSTALL_DIR=C:\ParqueRM
set GUIDE=%INSTALL_DIR%\NETWORK-DNS-SETUP.html
set NETWORK_CONFIG=%INSTALL_DIR%\config\dns-network.json

if exist "%GUIDE%" start "" "%GUIDE%"

for /f "usebackq delims=" %%g in (`powershell.exe -NoProfile -Command "try { $c=Get-Content '%NETWORK_CONFIG%' -Raw|ConvertFrom-Json; if($c.gateway){'http://'+$c.gateway} } catch {}"`) do set ROUTER_URL=%%g
if defined ROUTER_URL start "" "%ROUTER_URL%"

