@echo off
setlocal

set INSTALL_DIR=C:\ParqueRM
set CONFIG=%INSTALL_DIR%\config\parquerm.config.json

:: Read frontend URL from config and open the stable local URL in default browser
for /f "usebackq delims=" %%u in (`powershell.exe -NoProfile -Command "try { $c = Get-Content '%CONFIG%' -Raw | ConvertFrom-Json; if($c.frontendUrl){ $c.frontendUrl } else { 'http://parque.rm.local' } } catch { 'http://parque.rm.local' }"`) do set FRONTEND_URL=%%u

echo Checking ParqueRM services...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$services='ParqueRMBackend','ParqueRMFrontend','ParqueRMLocalName';" ^
  "foreach($name in $services){ $svc=Get-Service $name -ErrorAction SilentlyContinue; if($svc -and $svc.Status -ne 'Running'){ Start-Service $name -ErrorAction SilentlyContinue } };" ^
  "$deadline=(Get-Date).AddSeconds(45);" ^
  "do { try { $r=Invoke-WebRequest -UseBasicParsing -Uri '%FRONTEND_URL%/' -TimeoutSec 3; if($r.StatusCode -ge 200 -and $r.StatusCode -lt 400){ exit 0 } } catch {}; try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1/' -TimeoutSec 3; if($r.StatusCode -ge 200 -and $r.StatusCode -lt 400){ exit 0 } } catch {}; Start-Sleep -Seconds 2 } while((Get-Date) -lt $deadline);" ^
  "exit 1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] ParqueRM Frontend is not responding on %FRONTEND_URL% or http://127.0.0.1/
    echo Showing status...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\show-status.ps1" -InstallDir "%INSTALL_DIR%"
    echo.
    pause
    exit /b 1
)

echo Opening ParqueRM: %FRONTEND_URL%
start "" "%FRONTEND_URL%"

:: Also show status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\show-final-url.ps1" -InstallDir "%INSTALL_DIR%"
