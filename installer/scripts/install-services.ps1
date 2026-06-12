#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs ParqueRM Windows services (Backend + Frontend) using WinSW.

.DESCRIPTION
    Uses WinSW (Windows Service Wrapper) to register:
      - "ParqueRM Backend"  : NestJS on port 3000
      - "ParqueRM Frontend" : Caddy serving the dist folder on port 80
      - "ParqueRM Local Name": mDNS responder for parque.rm.local

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
$LogNetwork   = Join-Path $InstallDir 'logs\network'
$ConfigDir    = Join-Path $InstallDir 'config'
$ServicesDir  = Join-Path $InstallDir 'services'
$UploadsDir   = Join-Path $InstallDir 'data\uploads'
$DbReadyPath  = Join-Path $ConfigDir 'db-ready.json'

foreach ($d in @($LogBackend, $LogFrontend, $LogNetwork, $ServicesDir, (Join-Path $UploadsDir 'logos'))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

if (-not (Test-Path $DbReadyPath)) {
    Write-Error "Database initialization did not complete successfully. Missing marker: $DbReadyPath. Check $InstallDir\logs\db-init\ before installing services."
    exit 1
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
$caddyContent = @"
:80 {
    handle /uploads/* {
        reverse_proxy 127.0.0.1:3000
    }

    handle /api/* {
        reverse_proxy 127.0.0.1:3000
    }

    handle {
        root * $($FrontendDist -replace '\\', '/')
        try_files {path} /index.html
        file_server
    }

    log {
        output file $($LogFrontend -replace '\\', '/')/access.log
    }
}
"@
$caddyContent | Out-File -FilePath $caddyFile -Encoding utf8
Write-Host "  Wrote Caddyfile: $caddyFile" -ForegroundColor Green

# --- Helper: install one WinSW service ---------------------------------------
function ConvertTo-XmlEscaped([AllowNull()][string]$Value) {
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape($Value)
}

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
        $envName = ConvertTo-XmlEscaped $parts[0]
        $envValue = if ($parts.Count -gt 1) { ConvertTo-XmlEscaped $parts[1] } else { '' }
        $envXml += "    <env name=`"$envName`" value=`"$envValue`" />`n"
    }

    $xmlServiceId = ConvertTo-XmlEscaped $ServiceId
    $xmlDisplayName = ConvertTo-XmlEscaped $DisplayName
    $xmlDescription = ConvertTo-XmlEscaped $Description
    $xmlExecutable = ConvertTo-XmlEscaped $Executable
    $xmlArguments = ConvertTo-XmlEscaped $Arguments
    $xmlWorkingDir = ConvertTo-XmlEscaped $WorkingDir
    $xmlLogDir = ConvertTo-XmlEscaped $LogDir

    $xmlContent = @"
<service>
  <id>$xmlServiceId</id>
  <name>$xmlDisplayName</name>
  <description>$xmlDescription</description>
  <executable>$xmlExecutable</executable>
  <arguments>$xmlArguments</arguments>
  <workingdirectory>$xmlWorkingDir</workingdirectory>
  <startmode>Automatic</startmode>
  <logmode>rotate</logmode>
  <logpath>$xmlLogDir</logpath>
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
        if ($existing.Status -ne 'Stopped') {
            Stop-Service -Name $ServiceId -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
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
    -EnvVars      @("NODE_ENV=production", "UPLOADS_PATH=$UploadsDir", "PATH=$nodeDir;$env:PATH")

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

# --- Local name responder service --------------------------------------------
Write-Host "`nInstalling ParqueRM Local Name service..." -ForegroundColor Cyan
$localNameScript = Join-Path $InstallDir 'tools\installer-scripts\local-name-responder.ps1'
if (-not (Test-Path $localNameScript)) {
    Write-Error "Local name responder script not found at $localNameScript."
    exit 1
}

Install-WinSwService `
    -ServiceId    'ParqueRMLocalName' `
    -DisplayName  'ParqueRM Local Name' `
    -Description  'ParqueRM mDNS responder for parque.rm.local' `
    -Executable   'powershell.exe' `
    -Arguments    "-NoProfile -ExecutionPolicy Bypass -File `"$localNameScript`" -InstallDir `"$InstallDir`"" `
    -WorkingDir   (Split-Path $localNameScript -Parent) `
    -LogDir       $LogNetwork

# --- Start services -----------------------------------------------------------
Write-Host "`nStarting services..." -ForegroundColor Cyan

function Start-ParqueService {
    param([string]$ServiceId)

    $svcExe = Join-Path $ServicesDir "$ServiceId\$ServiceId.exe"
    $lastError = $null

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $svc = Get-Service -Name $ServiceId -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Write-Host "  [OK] $ServiceId is running" -ForegroundColor Green
            return
        }

        Write-Host "  Starting $ServiceId (attempt $attempt/3)..." -ForegroundColor Yellow
        try {
            Start-Service -Name $ServiceId -ErrorAction Stop
        } catch {
            $lastError = $_.Exception.Message
            if (Test-Path $svcExe) {
                & $svcExe start 2>&1 | Out-Null
            }
        }

        Start-Sleep -Seconds 8
        $svc.Refresh()
        if ($svc.Status -eq 'Running') {
            Write-Host "  [OK] $ServiceId is running" -ForegroundColor Green
            return
        }
    }

    if ($lastError) {
        Write-Error "Service $ServiceId did not start. Last error: $lastError"
    } else {
        Write-Error "Service $ServiceId did not start."
    }
    exit 1
}

function Wait-HttpOk {
    param(
        [string]$Name,
        [string]$Url,
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = ''

    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                Write-Host "  [OK] $Name responded: $Url" -ForegroundColor Green
                return
            }
        } catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 3
    }

    Write-Error "$Name did not respond at $Url. Last error: $lastError"
    exit 1
}

Start-ParqueService 'ParqueRMBackend'
Wait-HttpOk 'Backend health' 'http://127.0.0.1:3000/api/health' 90

Start-ParqueService 'ParqueRMFrontend'
Wait-HttpOk 'Frontend' 'http://127.0.0.1/' 45
Wait-HttpOk 'Frontend API proxy' 'http://127.0.0.1/api/health' 45

Start-ParqueService 'ParqueRMLocalName'

foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend', 'ParqueRMLocalName')) {
    $svc = Get-Service -Name $svcName -ErrorAction Stop
    if ($svc.Status -ne 'Running') {
        Write-Error "Service $svcName did not stay Running. Current status: $($svc.Status)"
        exit 1
    }
}

Write-Host ""
Write-Host "Services installed and started." -ForegroundColor Green
Write-Host "  Backend  : ParqueRMBackend" -ForegroundColor White
Write-Host "  Frontend : ParqueRMFrontend" -ForegroundColor White
Write-Host "  Local DNS: ParqueRMLocalName" -ForegroundColor White
