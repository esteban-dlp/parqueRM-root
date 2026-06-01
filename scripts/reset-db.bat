@echo off
cd /d "%~dp0.."

echo ADVERTENCIA: Esto borrara la base de datos local.
pause

docker compose down -v
echo Detectando IP LAN para park_config.system_lan_url...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare-docker-env.ps1"
if %ERRORLEVEL% neq 0 (
    echo [WARN] No se pudo detectar la IP. Docker usara el fallback configurado.
)

docker compose up -d --build

echo Base reiniciada.
pause
