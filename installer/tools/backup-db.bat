@echo off
setlocal EnableExtensions

set "INSTALL_DIR=%~dp0.."
for %%I in ("%INSTALL_DIR%") do set "INSTALL_DIR=%%~fI"
set "DB_FILE=%INSTALL_DIR%\data\parquerm.db"
set "BACKUP_DIR=%INSTALL_DIR%\backups"

if not exist "%DB_FILE%" (
    echo [ERROR] SQLite database not found:
    echo   %DB_FILE%
    pause
    exit /b 1
)

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "DATE_PART=%%c%%b%%a"
set "TIME_PART=%time::=%"
set "TIME_PART=%TIME_PART: =0%"
set "TIME_PART=%TIME_PART:.=%"
set "BACKUP_FILE=%BACKUP_DIR%\parquerm-%DATE_PART%-%TIME_PART%.db"

echo Stopping ParqueRM backend for a consistent SQLite backup...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Stop-Service ParqueRMBackend -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2"

copy /Y "%DB_FILE%" "%BACKUP_FILE%" >nul
set "RC=%ERRORLEVEL%"

echo Starting ParqueRM backend...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Service ParqueRMBackend -ErrorAction SilentlyContinue"

if not "%RC%"=="0" (
    echo [ERROR] Backup failed.
    pause
    exit /b %RC%
)

echo [OK] Backup created:
echo   %BACKUP_FILE%
pause
