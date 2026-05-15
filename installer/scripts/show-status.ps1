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
$sqlStatus,      $sqlColor      = Get-SqlStatus

$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
$frontendUrl = '(config no encontrado)'
$backendUrl  = ''
$swaggerUrl  = ''
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $frontendUrl = $cfg.frontendUrl
        $backendUrl  = $cfg.backendUrl
        $swaggerUrl  = $cfg.swaggerUrl
    } catch {}
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Estado de ParqueRM" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Backend  : " -NoNewline -ForegroundColor White
Write-Host $backendStatus -ForegroundColor $backendColor

Write-Host "  Frontend : " -NoNewline -ForegroundColor White
Write-Host $frontendStatus -ForegroundColor $frontendColor

Write-Host "  SQL Server: " -NoNewline -ForegroundColor White
Write-Host $sqlStatus -ForegroundColor $sqlColor

Write-Host ""
Write-Host "  URL local:" -ForegroundColor Yellow
Write-Host "    $frontendUrl" -ForegroundColor Cyan

if ($backendUrl) {
    Write-Host ""
    Write-Host "  URL para otras computadoras:" -ForegroundColor Yellow
    Write-Host "    $frontendUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  API:" -ForegroundColor Yellow
    Write-Host "    $backendUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Swagger:" -ForegroundColor Yellow
    Write-Host "    $swaggerUrl" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
