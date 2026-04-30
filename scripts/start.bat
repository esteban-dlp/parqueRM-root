@echo off
cd /d "%~dp0.."

echo Iniciando ParqueRM...
docker compose up -d --build

echo.
echo Sistema iniciado.
echo Frontend: http://localhost
echo Backend:  http://localhost:3000/api
echo SQL:      localhost,1433
echo.
pause