@echo off
echo ParqueRM - Apply Update
echo ========================
echo This applies a ParqueRM-Update.zip package to this server.
echo.
set /p PACKAGE_PATH=Enter path to ParqueRM-Update.zip (or folder):

if not exist "%PACKAGE_PATH%" (
    echo [ERROR] Path not found: %PACKAGE_PATH%
    pause
    exit /b 1
)

set EXTRACT_DIR=%TEMP%\ParqueRM-Update-Extract
if exist "%EXTRACT_DIR%" rmdir /s /q "%EXTRACT_DIR%"
mkdir "%EXTRACT_DIR%"

echo Extracting update package...
powershell.exe -NoProfile -Command "Expand-Archive -Path '%PACKAGE_PATH%' -DestinationPath '%EXTRACT_DIR%' -Force"

set UPDATE_DIR=%EXTRACT_DIR%\ParqueRM-Update
if not exist "%UPDATE_DIR%" set UPDATE_DIR=%EXTRACT_DIR%

echo Running update script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer-scripts\apply-update.ps1" -UpdatePackageDir "%UPDATE_DIR%"

if %ERRORLEVEL% equ 0 (
    echo [OK] Update applied successfully.
) else (
    echo [ERROR] Update failed. Check log in C:\ParqueRM\logs\updates\
)

if exist "%EXTRACT_DIR%" rmdir /s /q "%EXTRACT_DIR%"
pause
