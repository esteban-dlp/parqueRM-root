@echo off
REM ParqueRM - Build Installer
REM Calls build-installer.ps1 with all arguments passed through.
REM Usage: build-installer.bat [-SkipRuntimeValidation] [-SkipInstallerCompile] [-SkipNpmInstall] [-Clean] [-Verbose]

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-installer.ps1" %*
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
