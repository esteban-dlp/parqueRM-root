@echo off
cd /d "%~dp0.."

echo Iniciando ParqueRM...
echo Detectando IP LAN para park_config.system_lan_url...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare-docker-env.ps1"
if %ERRORLEVEL% neq 0 (
    echo [WARN] No se pudo detectar la IP. Docker usara el fallback configurado.
)

docker compose up -d --build

echo.
echo Sistema iniciado.
echo Frontend: http://localhost
echo Backend:  http://localhost:3000/api
echo SQL:      localhost,1433
echo.
pause
