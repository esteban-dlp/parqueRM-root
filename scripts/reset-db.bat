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

echo.
choice /C SN /M "¿Reinstalar con datos de ejemplo (visitantes, vehiculos, recibos demo)?"
if errorlevel 2 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-seed-demo-data.ps1" -Value false
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-seed-demo-data.ps1" -Value true
)

docker compose up -d --build

echo Base reiniciada.
pause
