#Requires -Version 5.1
#Requires -RunAsAdministrator
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Unregister-ScheduledTask `
    -TaskName 'ParqueRM_ClientNameRefresh' `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

$configureScript = Join-Path $InstallDir 'tools\installer-scripts\configure-local-name.ps1'
if (Test-Path $configureScript) {
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $configureScript `
        -InstallDir $InstallDir `
        -Remove
}

Write-Host 'ParqueRM client local-name configuration removed.' -ForegroundColor Green
