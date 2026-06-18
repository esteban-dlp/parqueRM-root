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
$dbReadyPath = Join-Path $InstallDir 'config\db-ready.json'

$errors = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $dbReadyPath)) {
    $errors.Add("Base de datos no inicializada correctamente: falta $dbReadyPath")
}

foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend', 'ParqueRMLocalName')) {
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
Test-HttpUrl 'Frontend por localhost' 'http://127.0.0.1/'
Test-HttpUrl 'API por localhost/Caddy' 'http://127.0.0.1/api/health'

try {
    $canonicalHost = if ($cfg.canonicalHost) { $cfg.canonicalHost } else { 'parquerm.local' }
    $resolved = [System.Net.Dns]::GetHostAddresses($canonicalHost) |
        Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
        ForEach-Object { $_.IPAddressToString }
    if (-not $resolved) {
        $errors.Add("La URL local no resuelve a IPv4: $canonicalHost")
    }
} catch {
    $errors.Add("La URL local no resuelve: $canonicalHost -- $($_.Exception.Message)")
}

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
    Write-Host "    $InstallDir\logs\network\" -ForegroundColor Cyan
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
Write-Host "  URL publica para la red local:" -ForegroundColor White
Write-Host ""
Write-Host "    $($cfg.frontendUrl)" -ForegroundColor Green
Write-Host ""
Write-Host "  Fallback por IP del servidor:" -ForegroundColor White
if ($cfg.currentIpv4Addresses) {
    foreach ($ip in @($cfg.currentIpv4Addresses)) {
        Write-Host "    http://$ip" -ForegroundColor Cyan
    }
} else {
    Write-Host "    Revise 'Ver estado de ParqueRM' para ver la IP actual." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Si parquerm.local no abre desde otra PC, instale el Modo Solo Cliente" -ForegroundColor Yellow
Write-Host "  en esa PC o use temporalmente el fallback por IP." -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
