@echo off
REM ParqueRM - Build Update Package
REM Calls build-update.ps1 with all arguments passed through.
REM Usage: build-update.bat [-SkipNpmInstall] [-SkipBuild] [-IncludeNodeModules]

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-update.ps1" %*
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Build update failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
