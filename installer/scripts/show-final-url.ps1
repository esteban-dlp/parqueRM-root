#Requires -Version 5.1
<#
.SYNOPSIS
    Shows the final installation URLs after install or update.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

$configPath = Join-Path $InstallDir 'config\parquerm.config.json'

if (-not (Test-Path $configPath)) {
    Write-Host "Config not found: $configPath" -ForegroundColor Red
    exit 1
}

$cfg = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ParqueRM se instalo correctamente." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tu aplicacion esta corriendo en:" -ForegroundColor White
Write-Host ""
Write-Host "  Frontend:" -ForegroundColor Yellow
Write-Host "    $($cfg.frontendUrl)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Backend API:" -ForegroundColor Yellow
Write-Host "    $($cfg.backendUrl)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Documentacion API:" -ForegroundColor Yellow
Write-Host "    $($cfg.swaggerUrl)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Cualquier computadora conectada a la misma red local" -ForegroundColor White
Write-Host "  puede acceder desde:" -ForegroundColor White
Write-Host ""
Write-Host "    $($cfg.frontendUrl)" -ForegroundColor Green
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
