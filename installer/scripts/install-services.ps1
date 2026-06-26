#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs ParqueRM Windows services using WinSW.

.DESCRIPTION
    Uses WinSW (Windows Service Wrapper) to register:
      - "ParqueRM Backend"  : NestJS on port 3000
      - "ParqueRM Frontend" : Caddy serving the dist folder on port 80
      - "ParqueRM Local Name": mDNS aliases and UDP LAN discovery

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

# --- Logging setup (before StrictMode so $script:LogFile is always defined) ---
$script:LogFile = $null
try {
    $logServicesDir = Join-Path $InstallDir 'logs\services'
    if (-not (Test-Path $logServicesDir)) {
        New-Item -ItemType Directory -Path $logServicesDir -Force | Out-Null
    }
    $script:LogFile = Join-Path $logServicesDir ("install-services-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".log")
    Add-Content -Path $script:LogFile -Value "=== install-services.ps1 started $(Get-Date) ===" -Encoding utf8
} catch {
    # Log dir creation failed; fall back to desktop
    $script:LogFile = Join-Path ([Environment]::GetFolderPath('Desktop')) 'parquerm-install-services.log'
    try { Add-Content -Path $script:LogFile -Value "=== install-services.ps1 started $(Get-Date) (log-dir fallback) ===" -Encoding utf8 } catch {}
}

function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    try { Add-Content -Path $script:LogFile -Value $line -Encoding utf8 } catch {}
}

function Invoke-WinSwCommand {
    param([string]$ExePath, [string]$Command, [string]$ServiceId)
    Write-Log "  WinSW ${Command}: $ExePath" 'Gray'
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $rawOutput = & $ExePath $Command 2>&1
        $exit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $outLines = @($rawOutput | ForEach-Object { "$_" } | Where-Object { $_ })
    if ($outLines.Count -gt 0) {
        $outLines | ForEach-Object { Write-Log "    [WinSW $Command] $_" 'Gray' }
    }
    return $exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global trap: log any unhandled terminating error
trap {
    $errMsg = "UNHANDLED ERROR: $($_.Exception.Message)`nAt: $($_.InvocationInfo.PositionMessage)"
    Write-Log $errMsg 'Red'
    exit 1
}

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
$ExistingCoreDnsService = Get-Service -Name 'ParqueRMDns' -ErrorAction SilentlyContinue

Write-Log "InstallDir : $InstallDir" 'Gray'
Write-Log "RuntimeDir : $RuntimeDir" 'Gray'
Write-Log "LogFile    : $script:LogFile" 'Gray'

foreach ($d in @($LogBackend, $LogFrontend, $LogNetwork, $ServicesDir, (Join-Path $UploadsDir 'logos'))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

if (-not (Test-Path $DbReadyPath)) {
    Write-Log "ERROR: db-ready.json missing at $DbReadyPath" 'Red'
    Write-Error "Database initialization did not complete successfully. Missing marker: $DbReadyPath. Check $InstallDir\logs\db-init\ before installing services."
    exit 1
}
Write-Log "db-ready.json found." 'Green'

# --- Locate WinSW -------------------------------------------------------------
$winsw = Join-Path $RuntimeDir 'winsw\WinSW.exe'
if (-not (Test-Path $winsw)) {
    $altNames = @('WinSW-x64.exe', 'winsw.exe', 'WinSW64.exe')
    foreach ($alt in $altNames) {
        $candidate = Join-Path $RuntimeDir "winsw\$alt"
        if (Test-Path $candidate) { $winsw = $candidate; break }
    }
}
if (-not (Test-Path $winsw)) {
    Write-Log "ERROR: WinSW not found in $RuntimeDir\winsw\" 'Red'
    $found = @(Get-ChildItem (Join-Path $RuntimeDir 'winsw') -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    Write-Log "  Contents of winsw dir: $($found -join ', ')" 'Yellow'
    Write-Error "WinSW not found at $RuntimeDir\winsw\. Place WinSW.exe there."
    exit 1
}
Write-Log "WinSW : $winsw" 'Gray'
try {
    $winswVer = (& $winsw --version 2>&1 | Select-Object -First 1)
    Write-Log "WinSW version: $winswVer" 'Gray'
} catch { Write-Log "WinSW version check skipped." 'Gray' }

# --- Locate Node.js -----------------------------------------------------------
$nodePath = Join-Path $RuntimeDir 'node\node.exe'
if (-not (Test-Path $nodePath)) {
    $sysNodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $sysNode = if ($sysNodeCmd) { $sysNodeCmd.Source } else { $null }
    if ($sysNode) { $nodePath = $sysNode } else {
        Write-Log "ERROR: node.exe not found." 'Red'
        Write-Error "node.exe not found in $RuntimeDir\node\ and not in PATH."
        exit 1
    }
}
$nodeDir = Split-Path $nodePath -Parent
Write-Log "Node  : $nodePath" 'Gray'

# --- Locate Caddy -------------------------------------------------------------
$caddyPath = Join-Path $RuntimeDir 'caddy\caddy.exe'
if (-not (Test-Path $caddyPath)) {
    Write-Log "ERROR: caddy.exe not found at $RuntimeDir\caddy\" 'Red'
    Write-Error "caddy.exe not found at $RuntimeDir\caddy\. Place caddy.exe there."
    exit 1
}
Write-Log "Caddy : $caddyPath" 'Gray'

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
Write-Log "Caddyfile written: $caddyFile" 'Green'

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

    Write-Log "  XML path : $xmlPath" 'Gray'
    Write-Log "  Exe path : $exePath" 'Gray'
    Write-Log "  Executable: $xmlExecutable" 'Gray'
    Write-Log "  Arguments : $Arguments" 'Gray'
    Write-Log "  WorkingDir: $xmlWorkingDir" 'Gray'

    # Check if already installed
    $existing = Get-Service -Name $ServiceId -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "  [UPDATE] $DisplayName -- re-installing" 'Yellow'
        if ($existing.Status -ne 'Stopped') {
            Stop-Service -Name $ServiceId -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        $uninstExit = Invoke-WinSwCommand $exePath 'uninstall' $ServiceId
        Write-Log "  WinSW uninstall exit code: $uninstExit" 'Gray'
        Start-Sleep -Seconds 2
    }

    $instExit = Invoke-WinSwCommand $exePath 'install' $ServiceId
    Write-Log "  WinSW install exit code: $instExit" 'Gray'
    if ($instExit -ne 0) {
        Write-Log "ERROR: WinSW install failed for $DisplayName (exit $instExit)" 'Red'
        Write-Error "Failed to install service: $DisplayName (WinSW exit $instExit)"
        exit 1
    }
    Write-Log "  [OK] $DisplayName installed" 'Green'
}

# --- Backend service ----------------------------------------------------------
Write-Log "`nInstalling ParqueRM Backend service..." 'Cyan'
$backendMain = Join-Path $BackendDir 'dist\main.js'
if (-not (Test-Path $backendMain)) {
    Write-Log "ERROR: Backend dist not found at $backendMain" 'Red'
    Write-Error "Backend dist not found at $backendMain. Run 'npm run build' first."
    exit 1
}
Write-Log "Backend main.js found: $backendMain" 'Gray'

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
Write-Log "`nInstalling ParqueRM Frontend service..." 'Cyan'

Install-WinSwService `
    -ServiceId    'ParqueRMFrontend' `
    -DisplayName  'ParqueRM Frontend' `
    -Description  'ParqueRM Caddy static file server (frontend)' `
    -Executable   $caddyPath `
    -Arguments    "run --config `"$caddyFile`"" `
    -WorkingDir   (Split-Path $caddyPath -Parent) `
    -LogDir       $LogFrontend

# --- Local name responder service --------------------------------------------
Write-Log "`nInstalling ParqueRM Local Name service..." 'Cyan'
$localNameScript = Join-Path $InstallDir 'tools\installer-scripts\local-name-responder.ps1'
if (-not (Test-Path $localNameScript)) {
    Write-Log "ERROR: local-name-responder.ps1 not found at $localNameScript" 'Red'
    Write-Error "Local name responder script not found at $localNameScript."
    exit 1
}
Write-Log "local-name-responder.ps1 found." 'Gray'

Install-WinSwService `
    -ServiceId    'ParqueRMLocalName' `
    -DisplayName  'ParqueRM Local Name' `
    -Description  'ParqueRM mDNS aliases and UDP LAN discovery' `
    -Executable   'powershell.exe' `
    -Arguments    "-NoProfile -ExecutionPolicy Bypass -File `"$localNameScript`" -InstallDir `"$InstallDir`" -HostNames parquerm.local,parque.rm.local -MdnsPort 5353 -DiscoveryPort 47880" `
    -WorkingDir   (Split-Path $localNameScript -Parent) `
    -LogDir       $LogNetwork

# --- Start services -----------------------------------------------------------
Write-Log "`nStarting services..." 'Cyan'

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

        Write-Log "  Starting $ServiceId (attempt $attempt/3)..." 'Yellow'
        try {
            Start-Service -Name $ServiceId -ErrorAction Stop
        } catch {
            $lastError = $_.Exception.Message
            if (Test-Path $svcExe) {
                # Fallback to the WinSW-wrapped exe directly. Same stderr/Stop
                # landmine as above: relax ErrorActionPreference for the call.
                $previousErrorActionPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    & $svcExe start 2>&1 | Out-Null
                } finally {
                    $ErrorActionPreference = $previousErrorActionPreference
                }
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
        Write-Log "ERROR: $ServiceId did not start. Last error: $lastError" 'Red'
        Write-Error "Service $ServiceId did not start. Last error: $lastError"
    } else {
        Write-Log "ERROR: $ServiceId did not start." 'Red'
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

    Write-Log "ERROR: $Name did not respond at $Url. Last error: $lastError" 'Red'
    Write-Error "$Name did not respond at $Url. Last error: $lastError"
    exit 1
}

function Start-OptionalService {
    param([string]$ServiceId)

    $svc = Get-Service -Name $ServiceId -ErrorAction SilentlyContinue
    if (-not $svc) { return }

    try {
        if ($svc.Status -ne 'Running') {
            Start-Service -Name $ServiceId -ErrorAction Stop
            Start-Sleep -Seconds 3
            $svc.Refresh()
        }
        if ($svc.Status -eq 'Running') {
            Write-Host "  [OK] Optional legacy service $ServiceId is running" -ForegroundColor Green
        } else {
            Write-Warning "Optional legacy service $ServiceId did not reach Running. Main ParqueRM LAN flow does not depend on it."
        }
    } catch {
        Write-Warning "Could not start optional legacy service ${ServiceId}: $($_.Exception.Message). Main ParqueRM LAN flow does not depend on it."
    }
}

Start-ParqueService 'ParqueRMBackend'
Wait-HttpOk 'Backend health' 'http://127.0.0.1:3000/api/health' 90

Start-ParqueService 'ParqueRMFrontend'
Wait-HttpOk 'Frontend' 'http://127.0.0.1/' 45
Wait-HttpOk 'Frontend API proxy' 'http://127.0.0.1/api/health' 45

Start-ParqueService 'ParqueRMLocalName'
if ($ExistingCoreDnsService) {
    Start-OptionalService 'ParqueRMDns'
}

foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend', 'ParqueRMLocalName')) {
    $svc = Get-Service -Name $svcName -ErrorAction Stop
    if ($svc.Status -ne 'Running') {
        Write-Log "ERROR: $svcName did not stay Running. Status: $($svc.Status)" 'Red'
        Write-Error "Service $svcName did not stay Running. Current status: $($svc.Status)"
        exit 1
    }
    Write-Log "  [OK] $svcName is Running" 'Green'
}

Write-Log "" 'White'
Write-Log "Services installed and started." 'Green'
Write-Log "  Backend  : ParqueRMBackend" 'White'
Write-Log "  Frontend : ParqueRMFrontend" 'White'
Write-Log "  Local    : ParqueRMLocalName" 'White'
if ($ExistingCoreDnsService) {
    Write-Log "  Legacy DNS preserved: ParqueRMDns" 'Gray'
}
Write-Log "Log: $script:LogFile" 'Gray'
