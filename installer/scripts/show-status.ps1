#Requires -Version 5.1
<#
.SYNOPSIS
    Shows the current running status of all ParqueRM services and access URLs.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

function Get-SvcStatus([string]$name) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc)                     { return 'No instalado', 'Red' }
    if ($svc.Status -eq 'Running')     { return 'Corriendo',    'Green' }
    if ($svc.Status -eq 'Stopped')     { return 'Detenido',     'Yellow' }
    return $svc.Status.ToString(), 'Gray'
}

function Get-SqlStatus {
    $svc = Get-Service -Name 'MSSQLSERVER' -ErrorAction SilentlyContinue
    if (-not $svc) { $svc = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue }
    if (-not $svc) { return 'No instalado', 'Red' }
    if ($svc.Status -eq 'Running') { return 'Corriendo', 'Green' }
    return 'Detenido', 'Yellow'
}

$backendStatus,  $backendColor  = Get-SvcStatus 'ParqueRMBackend'
$frontendStatus, $frontendColor = Get-SvcStatus 'ParqueRMFrontend'
$localNameStatus, $localNameColor = Get-SvcStatus 'ParqueRMLocalName'
$sqlStatus,      $sqlColor      = Get-SqlStatus

$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
$frontendUrl = '(config no encontrado)'
$backendUrl  = ''
$swaggerUrl  = ''
$recommendedUrl = ''
$canonicalHost = 'parque.rm.local'
$fallbackUrls = @()
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $frontendUrl = $cfg.frontendUrl
        $backendUrl  = $cfg.backendUrl
        $swaggerUrl  = $cfg.swaggerUrl
        if ($cfg.recommendedUrl) { $recommendedUrl = $cfg.recommendedUrl }
        if ($cfg.canonicalHost) { $canonicalHost = $cfg.canonicalHost }
        if ($cfg.fallbackUrls) { $fallbackUrls = @($cfg.fallbackUrls) }
    } catch {}
}
if (-not $recommendedUrl) { $recommendedUrl = $frontendUrl }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Estado de ParqueRM                                        " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Backend  : " -NoNewline -ForegroundColor White
Write-Host $backendStatus -ForegroundColor $backendColor

Write-Host "  Frontend : " -NoNewline -ForegroundColor White
Write-Host $frontendStatus -ForegroundColor $frontendColor

Write-Host "  SQL Server: " -NoNewline -ForegroundColor White
Write-Host $sqlStatus -ForegroundColor $sqlColor
Write-Host "  URL local : " -NoNewline -ForegroundColor White
Write-Host $localNameStatus -ForegroundColor $localNameColor

Write-Host ""
Write-Host "  URL recomendada:" -ForegroundColor Yellow
Write-Host "    $recommendedUrl" -ForegroundColor Cyan

if ($backendUrl) {
    Write-Host ""
    Write-Host "  Host local:" -ForegroundColor Yellow
    Write-Host "    $canonicalHost" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  API:" -ForegroundColor Yellow
    Write-Host "    $backendUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Swagger:" -ForegroundColor Yellow
    Write-Host "    $swaggerUrl" -ForegroundColor Cyan
}

if ($fallbackUrls.Count -gt 0) {
    Write-Host ""
    Write-Host "  Fallbacks:" -ForegroundColor Yellow
    foreach ($url in $fallbackUrls) {
        Write-Host "    $url" -ForegroundColor Gray
    }
}

# --- Puertos ------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Puertos" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

function Test-Port([int]$port) {
    $result = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($result) { return 'Escuchando', 'Green' } else { return 'Sin respuesta', 'Red' }
}

$p80status,   $p80color   = Test-Port 80
$p3000status, $p3000color = Test-Port 3000
$p1433status, $p1433color = Test-Port 1433

Write-Host "  Puerto 80   (Frontend): " -NoNewline -ForegroundColor White
Write-Host $p80status -ForegroundColor $p80color
Write-Host "  Puerto 3000 (Backend) : " -NoNewline -ForegroundColor White
Write-Host $p3000status -ForegroundColor $p3000color
Write-Host "  Puerto 1433 (SQL)     : " -NoNewline -ForegroundColor White
Write-Host $p1433status -ForegroundColor $p1433color

$udp5353 = netstat -ano -p udp 2>$null | Select-String -Pattern ':5353\s'
Write-Host "  UDP 5353  (mDNS)      : " -NoNewline -ForegroundColor White
if ($udp5353) { Write-Host 'Activo' -ForegroundColor Green } else { Write-Host 'No detectado' -ForegroundColor Yellow }

# --- Red / IP -----------------------------------------------------------------
$currentIps = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.*' } |
    Select-Object -ExpandProperty IPAddress)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Red" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  IP(s) actuales        : " -NoNewline -ForegroundColor White
if ($currentIps.Count -gt 0) {
    Write-Host ($currentIps -join ', ') -ForegroundColor Cyan
} else {
    Write-Host '(no detectada)' -ForegroundColor Gray
}

Write-Host "  Resolucion $canonicalHost : " -NoNewline -ForegroundColor White
try {
    $resolved = [System.Net.Dns]::GetHostAddresses($canonicalHost) |
        Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
        ForEach-Object { $_.IPAddressToString }
    if ($resolved) {
        Write-Host ($resolved -join ', ') -ForegroundColor Cyan
    } else {
        Write-Host 'sin IPv4' -ForegroundColor Yellow
    }
} catch {
    Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Log del backend ----------------------------------------------------------
$backendLogDir = Join-Path $InstallDir 'logs\backend'
$backendLogFile = Get-ChildItem -Path $backendLogDir -Filter '*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($backendLogFile) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Ultimas 10 lineas del log de Backend" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Get-Content $backendLogFile.FullName -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
}

$frontendLogDir = Join-Path $InstallDir 'logs\frontend'
$frontendLogFile = Get-ChildItem -Path $frontendLogDir -Filter '*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($frontendLogFile) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Ultimas 10 lineas del log de Frontend" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Get-Content $frontendLogFile.FullName -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
