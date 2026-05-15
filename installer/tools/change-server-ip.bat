@echo off
setlocal enabledelayedexpansion

set INSTALL_DIR=C:\ParqueRM

echo ParqueRM - Change Server IP
echo ============================
echo This updates all config files with a new server IP address.
echo Run this if the server's IP address has changed.
echo.

:: Show detected IPs
echo Detected network addresses:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\get-local-ip.ps1" 2>nul
echo.

set /p NEW_IP=Enter new server IP address:
if "%NEW_IP%"=="" (
    echo [ERROR] IP address cannot be empty.
    pause & exit /b 1
)

set /p DB_PASS=Enter SQL Server SA password:
if "%DB_PASS%"=="" (
    echo [ERROR] Password cannot be empty.
    pause & exit /b 1
)

:: Read JWT secrets from existing .env using PowerShell (avoids findstr ambiguity)
echo.
echo Reading existing JWT secrets from .env...
for /f "usebackq delims=" %%s in (`powershell.exe -NoProfile -Command "try { $env = Get-Content '%INSTALL_DIR%\app\backend\.env' -ErrorAction Stop; ($env | Where-Object { $_ -match '^JWT_SECRET=' } | Select-Object -First 1) -replace '^JWT_SECRET=','' } catch { '' }"`) do set JWT_SECRET=%%s
for /f "usebackq delims=" %%s in (`powershell.exe -NoProfile -Command "try { $env = Get-Content '%INSTALL_DIR%\app\backend\.env' -ErrorAction Stop; ($env | Where-Object { $_ -match '^JWT_REFRESH_SECRET=' } | Select-Object -First 1) -replace '^JWT_REFRESH_SECRET=','' } catch { '' }"`) do set JWT_REFRESH=%%s

if "%JWT_SECRET%"=="" (
    echo [WARN] Could not read JWT_SECRET from .env. You must enter it manually.
    set /p JWT_SECRET=Enter JWT Secret:
)
if "%JWT_REFRESH%"=="" (
    echo [WARN] Could not read JWT_REFRESH_SECRET from .env. You must enter it manually.
    set /p JWT_REFRESH=Enter JWT Refresh Secret:
)

echo.
echo Updating configuration for IP: %NEW_IP%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\generate-config.ps1" ^
    -InstallDir "%INSTALL_DIR%" ^
    -ServerIp "%NEW_IP%" ^
    -DbPassword "%DB_PASS%" ^
    -JwtSecret "%JWT_SECRET%" ^
    -JwtRefreshSecret "%JWT_REFRESH%"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Configuration update failed.
    pause & exit /b 1
)

echo.
echo Restarting services to apply new configuration...
net stop ParqueRMFrontend >nul 2>&1
net stop ParqueRMBackend  >nul 2>&1
timeout /t 3 /nobreak >nul
net start ParqueRMBackend  >nul 2>&1
net start ParqueRMFrontend >nul 2>&1

echo [OK] Services restarted.
echo.
echo Other computers on the LAN can now access ParqueRM at:
echo   http://%NEW_IP%
echo.
pause
