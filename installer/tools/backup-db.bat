@echo off
setlocal enabledelayedexpansion

set INSTALL_DIR=C:\ParqueRM
set BACKUP_DIR=%INSTALL_DIR%\backups

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: Detect sqlcmd -- try runtime cache first, then PATH
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

set /p DB_PASS=Enter SQL Server SA password:

:: Build timestamp without spaces
for /f "tokens=1-3 delims=/ " %%a in ("%DATE%") do set D=%%c%%a%%b
for /f "tokens=1-3 delims=:. " %%a in ("%TIME: =0%") do set T=%%a%%b%%c
set TIMESTAMP=%D%-%T%
set BACKUP_FILE=%BACKUP_DIR%\ParqueRM-backup-%TIMESTAMP%.bak

echo.
echo Creating backup...
echo   File: %BACKUP_FILE%
echo.

"%SQLCMD_EXE%" -S localhost,1433 -U sa -P "%DB_PASS%" -Q "BACKUP DATABASE [ParqueRM] TO DISK='%BACKUP_FILE%' WITH FORMAT, INIT, NAME='ParqueRM Manual Backup'" -b

if %ERRORLEVEL% equ 0 (
    echo.
    echo [OK] Backup created: %BACKUP_FILE%
) else (
    echo.
    echo [ERROR] Backup failed. Check that SQL Server is running and the password is correct.
)
echo.
pause
