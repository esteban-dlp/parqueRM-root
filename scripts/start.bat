@echo off
cd /d "%~dp0.."

echo Iniciando ParqueRM...
echo Detectando IP LAN para park_config.system_lan_url...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare-docker-env.ps1"
if %ERRORLEVEL% neq 0 (
    echo [WARN] No se pudo detectar la IP. Docker usara el fallback configurado.
)

if exist .env (
    findstr /B "SEED_DEMO_DATA=" .env >nul 2>&1
    if errorlevel 1 (
        echo.
        choice /C SN /M "¿Instalar con datos de ejemplo (visitantes, vehiculos, recibos demo)?"
        if errorlevel 2 (
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-seed-demo-data.ps1" -Value false
        ) else (
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-seed-demo-data.ps1" -Value true
        )
    )
)

docker compose up -d --build

echo.
echo Sistema iniciado.
echo Frontend: http://localhost
echo Backend:  http://localhost:3000/api
echo SQL:      localhost,1433
echo.
pause
