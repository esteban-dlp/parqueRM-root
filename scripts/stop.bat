@echo off
cd /d "%~dp0.."

echo Deteniendo ParqueRM...
docker compose down

echo Sistema detenido.
pause