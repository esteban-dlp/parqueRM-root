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

$errors = New-Object System.Collections.Generic.List[string]

foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        $errors.Add("Servicio no instalado: $svcName")
    } elseif ($svc.Status -ne 'Running') {
        $errors.Add("Servicio detenido: $svcName ($($svc.Status))")
    }
}

function Test-HttpUrl([string]$Name, [string]$Url) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 20
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
            $errors.Add("$Name respondio HTTP $($response.StatusCode): $Url")
        }
    } catch {
        $errors.Add("$Name no responde: $Url -- $($_.Exception.Message)")
    }
}

Start-Sleep -Seconds 3
Test-HttpUrl 'Frontend' $cfg.frontendUrl
Test-HttpUrl 'Backend health' "$($cfg.backendUrl)/health"
Test-HttpUrl 'Database health' "$($cfg.backendUrl)/health/database"

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  ParqueRM se instalo, pero no esta funcionando correctamente." -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    foreach ($err in $errors) {
        Write-Host "  - $err" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  Revise estos logs:" -ForegroundColor White
    Write-Host "    $InstallDir\logs\backend\ParqueRMBackend.err.log" -ForegroundColor Cyan
    Write-Host "    $InstallDir\logs\db-init\" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

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
