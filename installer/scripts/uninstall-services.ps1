#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Stops and removes ParqueRM Windows services.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ServicesDir = Join-Path $InstallDir 'services'
$serviceIds  = @('ParqueRMBackend', 'ParqueRMFrontend')

foreach ($id in $serviceIds) {
    $svc = Get-Service -Name $id -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "  [SKIP] $id -- not installed" -ForegroundColor Gray
        continue
    }

    if ($svc.Status -eq 'Running') {
        Write-Host "  Stopping $id ..." -ForegroundColor Yellow
        Stop-Service -Name $id -Force
        Start-Sleep -Seconds 2
    }

    $svcExe = Join-Path $ServicesDir "$id\$id.exe"
    if (Test-Path $svcExe) {
        & $svcExe uninstall
        Write-Host "  [REMOVED] $id" -ForegroundColor Green
    } else {
        # Fallback: use sc.exe
        sc.exe delete $id | Out-Null
        Write-Host "  [REMOVED] $id (via sc.exe)" -ForegroundColor Green
    }
}

Write-Host "Services removed." -ForegroundColor Cyan
