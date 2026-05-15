#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs ParqueRM Windows services (Backend + Frontend) using WinSW.

.DESCRIPTION
    Uses WinSW (Windows Service Wrapper) to register:
      - "ParqueRM Backend"  : NestJS on port 3000
      - "ParqueRM Frontend" : Caddy serving the dist folder on port 80

    WinSW binary must exist in runtime-cache\winsw\WinSW.exe
    Node.js must exist in runtime-cache\node\ or be installed system-wide.
    Caddy must exist in runtime-cache\caddy\caddy.exe

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM

.PARAMETER RuntimeDir
    Where runtime binaries (node, caddy, winsw) were copied during install.
    Default: InstallDir\runtime
#>
param(
    [string]$InstallDir  = 'C:\ParqueRM',
    [string]$RuntimeDir  = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RuntimeDir)) { $RuntimeDir = Join-Path $InstallDir 'runtime' }

$BackendDir   = Join-Path $InstallDir 'app\backend'
$FrontendDist = Join-Path $InstallDir 'app\frontend\dist'
$LogBackend   = Join-Path $InstallDir 'logs\backend'
$LogFrontend  = Join-Path $InstallDir 'logs\frontend'
$ConfigDir    = Join-Path $InstallDir 'config'
$ServicesDir  = Join-Path $InstallDir 'services'

foreach ($d in @($LogBackend, $LogFrontend, $ServicesDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# --- Locate WinSW -------------------------------------------------------------
$winsw = Join-Path $RuntimeDir 'winsw\WinSW.exe'
if (-not (Test-Path $winsw)) {
    # Try alternate names
    $altNames = @('WinSW-x64.exe', 'winsw.exe', 'WinSW64.exe')
    foreach ($alt in $altNames) {
        $candidate = Join-Path $RuntimeDir "winsw\$alt"
        if (Test-Path $candidate) { $winsw = $candidate; break }
    }
}
if (-not (Test-Path $winsw)) {
    Write-Error "WinSW not found at $RuntimeDir\winsw\. Place WinSW.exe there."
    exit 1
}
Write-Host "Using WinSW: $winsw" -ForegroundColor Gray

# --- Locate Node.js -----------------------------------------------------------
$nodePath = Join-Path $RuntimeDir 'node\node.exe'
if (-not (Test-Path $nodePath)) {
    $sysNodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $sysNode = if ($sysNodeCmd) { $sysNodeCmd.Source } else { $null }
    if ($sysNode) { $nodePath = $sysNode } else {
        Write-Error "node.exe not found in $RuntimeDir\node\ and not in PATH."
        exit 1
    }
}
$nodeDir = Split-Path $nodePath -Parent
Write-Host "Using Node: $nodePath" -ForegroundColor Gray

# --- Locate Caddy -------------------------------------------------------------
$caddyPath = Join-Path $RuntimeDir 'caddy\caddy.exe'
if (-not (Test-Path $caddyPath)) {
    Write-Error "caddy.exe not found at $RuntimeDir\caddy\. Place caddy.exe there."
    exit 1
}
Write-Host "Using Caddy: $caddyPath" -ForegroundColor Gray

# --- Caddyfile ----------------------------------------------------------------
$caddyFile = Join-Path $InstallDir 'config\Caddyfile'
if (-not (Test-Path $caddyFile)) {
    $caddyContent = @"
:80 {
    root * $($FrontendDist -replace '\\', '/')
    file_server
    try_files {path} /index.html
    log {
        output file $($LogFrontend -replace '\\', '/')/access.log
    }
}
"@
    $caddyContent | Out-File -FilePath $caddyFile -Encoding utf8
    Write-Host "  Created Caddyfile: $caddyFile" -ForegroundColor Green
}

# --- Helper: install one WinSW service ---------------------------------------
function Install-WinSwService {
    param(
        [string]$ServiceId,
        [string]$DisplayName,
        [string]$Description,
        [string]$Executable,
        [string]$Arguments,
        [string]$WorkingDir,
        [string]$LogDir,
        [string[]]$EnvVars = @()
    )

    $svcDir  = Join-Path $ServicesDir $ServiceId
    $xmlPath = Join-Path $svcDir "$ServiceId.xml"
    $exePath = Join-Path $svcDir "$ServiceId.exe"

    if (-not (Test-Path $svcDir)) { New-Item -ItemType Directory -Path $svcDir -Force | Out-Null }

    # Copy WinSW to service directory with service name
    Copy-Item -Path $winsw -Destination $exePath -Force

    $envXml = ''
    foreach ($ev in $EnvVars) {
        $parts = $ev -split '=', 2
        $envXml += "    <env name=`"$($parts[0])`" value=`"$($parts[1])`" />`n"
    }

    $xmlContent = @"
<service>
  <id>$ServiceId</id>
  <name>$DisplayName</name>
  <description>$Description</description>
  <executable>$Executable</executable>
  <arguments>$Arguments</arguments>
  <workingdirectory>$WorkingDir</workingdirectory>
  <startmode>Automatic</startmode>
  <logmode>rotate</logmode>
  <logpath>$LogDir</logpath>
  <onfailure action="restart" delay="10 sec"/>
  <onfailure action="restart" delay="20 sec"/>
  <onfailure action="none"/>
$envXml</service>
"@
    $xmlContent | Out-File -FilePath $xmlPath -Encoding utf8

    # Check if already installed
    $existing = Get-Service -Name $ServiceId -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  [UPDATE] $DisplayName -- re-installing" -ForegroundColor Yellow
        & $exePath uninstall 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }

    & $exePath install
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install service: $DisplayName"
        exit 1
    }
    Write-Host "  [OK] $DisplayName installed" -ForegroundColor Green
}

# --- Backend service ----------------------------------------------------------
Write-Host "`nInstalling ParqueRM Backend service..." -ForegroundColor Cyan
$backendMain = Join-Path $BackendDir 'dist\main.js'
if (-not (Test-Path $backendMain)) {
    Write-Error "Backend dist not found at $backendMain. Run 'npm run build' first."
    exit 1
}

Install-WinSwService `
    -ServiceId    'ParqueRMBackend' `
    -DisplayName  'ParqueRM Backend' `
    -Description  'ParqueRM NestJS REST API backend' `
    -Executable   $nodePath `
    -Arguments    "dist\main.js" `
    -WorkingDir   $BackendDir `
    -LogDir       $LogBackend `
    -EnvVars      @("NODE_ENV=production", "PATH=$nodeDir;$env:PATH")

# Set env file path via SC (WinSW reads XML env but also inherits system env)
# The .env is loaded by the backend via @nestjs/config dotenv support

# --- Frontend service ---------------------------------------------------------
Write-Host "`nInstalling ParqueRM Frontend service..." -ForegroundColor Cyan

Install-WinSwService `
    -ServiceId    'ParqueRMFrontend' `
    -DisplayName  'ParqueRM Frontend' `
    -Description  'ParqueRM Caddy static file server (frontend)' `
    -Executable   $caddyPath `
    -Arguments    "run --config `"$caddyFile`"" `
    -WorkingDir   (Split-Path $caddyPath -Parent) `
    -LogDir       $LogFrontend

# --- Start services -----------------------------------------------------------
Write-Host "`nStarting services..." -ForegroundColor Cyan
Start-Service 'ParqueRMBackend'  -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Service 'ParqueRMFrontend' -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Services installed and started." -ForegroundColor Green
Write-Host "  Backend  : ParqueRMBackend" -ForegroundColor White
Write-Host "  Frontend : ParqueRMFrontend" -ForegroundColor White
