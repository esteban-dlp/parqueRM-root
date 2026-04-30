@echo off
cd /d "%~dp0.."

echo ADVERTENCIA: Esto borrara la base de datos local.
pause

docker compose down -v
docker compose up -d --build

echo Base reiniciada.
pause