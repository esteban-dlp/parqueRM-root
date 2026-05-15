@echo off
setlocal enabledelayedexpansion

set INSTALL_DIR=C:\ParqueRM

:: Detect sqlcmd
set SQLCMD_EXE=
if exist "%INSTALL_DIR%\runtime\sqlcmd\sqlcmd.exe" (
    set SQLCMD_EXE=%INSTALL_DIR%\runtime\sqlcmd\sqlcmd.exe
) else (
    where sqlcmd >nul 2>&1
    if !ERRORLEVEL! equ 0 set SQLCMD_EXE=sqlcmd
)
if "%SQLCMD_EXE%"=="" (
    echo [ERROR] sqlcmd.exe not found.
    echo Place sqlcmd.exe in %INSTALL_DIR%\runtime\sqlcmd\ or install SQL Server tools.
    pause & exit /b 1
)

echo ParqueRM - Restore Database
echo ============================
echo WARNING: This will OVERWRITE the current database with the backup.
echo All data entered after the backup will be LOST.
echo.
set /p BACKUP_FILE=Enter full path to .bak file:
if not exist "%BACKUP_FILE%" (
    echo [ERROR] File not found: %BACKUP_FILE%
    pause & exit /b 1
)

echo.
set /p CONFIRM=Type YES to confirm restore:
if /i not "%CONFIRM%"=="YES" (
    echo Cancelled.
    pause & exit /b 0
)

set /p DB_PASS=Enter SQL Server SA password:

echo.
echo Stopping ParqueRM services...
net stop ParqueRMFrontend >nul 2>&1
net stop ParqueRMBackend  >nul 2>&1

echo Restoring database from: %BACKUP_FILE%
"%SQLCMD_EXE%" -S localhost,1433 -U sa -P "%DB_PASS%" -Q "ALTER DATABASE [ParqueRM] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [ParqueRM] FROM DISK='%BACKUP_FILE%' WITH REPLACE; ALTER DATABASE [ParqueRM] SET MULTI_USER;" -b

if %ERRORLEVEL% equ 0 (
    echo [OK] Restore complete.
) else (
    echo [ERROR] Restore failed. Check SQL Server logs.
    echo The database may be in an inconsistent state.
    echo Restart SQL Server and try again.
    goto :restart
)

:restart
echo.
echo Restarting services...
net start ParqueRMBackend  >nul 2>&1
net start ParqueRMFrontend >nul 2>&1
echo [OK] Services restarted.
echo.
pause
