@echo off
setlocal EnableExtensions

set "INSTALL_DIR=%~dp0.."
for %%I in ("%INSTALL_DIR%") do set "INSTALL_DIR=%%~fI"
set "DB_FILE=%INSTALL_DIR%\data\parquerm.db"
set "BACKUP_DIR=%INSTALL_DIR%\backups"

if "%~1"=="" (
    echo Usage:
    echo   restore-db.bat "C:\path\to\backup.db"
    echo.
    echo Available backups:
    if exist "%BACKUP_DIR%" dir /b /o-d "%BACKUP_DIR%\*.db"
    pause
    exit /b 1
)

set "BACKUP_FILE=%~1"
if not exist "%BACKUP_FILE%" (
    echo [ERROR] Backup file not found:
    echo   %BACKUP_FILE%
    pause
    exit /b 1
)

if not exist "%INSTALL_DIR%\data" mkdir "%INSTALL_DIR%\data"

echo Stopping ParqueRM services...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Stop-Service ParqueRMBackend,ParqueRMFrontend -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2"

if exist "%DB_FILE%" (
    copy /Y "%DB_FILE%" "%DB_FILE%.before-restore" >nul
)

copy /Y "%BACKUP_FILE%" "%DB_FILE%" >nul
set "RC=%ERRORLEVEL%"

echo Starting ParqueRM services...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Service ParqueRMBackend,ParqueRMFrontend -ErrorAction SilentlyContinue"

if not "%RC%"=="0" (
    echo [ERROR] Restore failed.
    pause
    exit /b %RC%
)

echo [OK] Database restored:
echo   %DB_FILE%
pause
