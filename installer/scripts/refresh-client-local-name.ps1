#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Discovers ParqueRM and keeps parquerm.local working on a Windows client.

.DESCRIPTION
    This script edits the Windows hosts file and is also used by the scheduled
    task ParqueRM_ClientNameRefresh. It never deletes an existing mapping when
    the server cannot be found.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string]$PreferredServerIp = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = Join-Path $InstallDir 'logs\network'
$configDir = Join-Path $InstallDir 'config'
foreach ($dir in @($logDir, $configDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}
$logFile = Join-Path $logDir 'client-name-refresh.log'
$configPath = Join-Path $configDir 'parquerm-client.json'
$canonicalUrl = 'http://parquerm.local'
$hostNames = @('parquerm.local', 'parque.rm.local', 'parque.rm.home.arpa')

function Write-Log([string]$Message, [string]$Level = 'INFO') {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

function ConvertTo-Ipv4Text([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Value.Trim(), [ref]$parsed)) { return '' }
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return '' }
    return $parsed.IPAddressToString
}

function Read-ExistingClientConfig {
    if (-not (Test-Path $configPath)) { return $null }
    try {
        return Get-Content $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-Log "Could not read previous client configuration: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Invoke-Discovery([string]$ManualIp, [string]$KnownIp) {
    $discoverScript = Join-Path $InstallDir 'tools\installer-scripts\discover-parquerm-server.ps1'
    if (-not (Test-Path $discoverScript)) { throw "Discovery script not found: $discoverScript" }

    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $discoverScript,
        '-Json',
        '-Quiet'
    )
    if (-not [string]::IsNullOrWhiteSpace($ManualIp)) {
        $args += @('-PreferredServerIp', $ManualIp)
    }
    if (-not [string]::IsNullOrWhiteSpace($KnownIp)) {
        $args += @('-KnownServerIp', $KnownIp)
    }

    $output = @(& powershell.exe @args)
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | ForEach-Object { $_.ToString() }) -join "`n"

    try {
        $result = $jsonText | ConvertFrom-Json
    } catch {
        if ($jsonText) { Write-Log $jsonText 'WARN' }
        throw "Discovery did not return valid JSON. Exit code: $exitCode"
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Result = $result
    }
}

function Configure-Hosts([string]$ServerIp) {
    $configureScript = Join-Path $InstallDir 'tools\installer-scripts\configure-local-name.ps1'
    if (-not (Test-Path $configureScript)) { throw "Local-name script not found: $configureScript" }

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $configureScript `
        -InstallDir $InstallDir `
        -TargetIp $ServerIp `
        -HostNames $hostNames
    if ($LASTEXITCODE -ne 0) {
        throw "Could not configure parquerm.local for $ServerIp."
    }
}

function Test-CanonicalUrl([string]$ExpectedInstanceId) {
    try {
        $health = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri "$canonicalUrl/api/health" `
            -TimeoutSec 10 `
            -Headers @{ 'Cache-Control' = 'no-cache' }
        if ($health.StatusCode -lt 200 -or $health.StatusCode -ge 400) {
            throw "HTTP $($health.StatusCode)"
        }

        $body = $health.Content | ConvertFrom-Json
        if ($body.app -ne 'ParqueRM') { throw 'Health endpoint did not identify ParqueRM.' }
        if ([string]::IsNullOrWhiteSpace([string]$body.instanceId)) { throw 'Health endpoint did not include instanceId.' }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedInstanceId) -and
            $body.instanceId -ne $ExpectedInstanceId) {
            throw "Configured URL points to instance $($body.instanceId), expected $ExpectedInstanceId."
        }
    } catch {
        throw "The local URL was configured but health validation failed: $($_.Exception.Message)"
    }
}

Write-Log 'Modo Solo Cliente requiere administrador porque actualiza hosts y registra una tarea programada.'

$existing = Read-ExistingClientConfig
$knownServerIp = ''
$knownInstanceId = ''
if ($existing) {
    if ($existing.serverIp) { $knownServerIp = ConvertTo-Ipv4Text ([string]$existing.serverIp) }
    if ($existing.instanceId) { $knownInstanceId = [string]$existing.instanceId }
}

$manualIp = ConvertTo-Ipv4Text $PreferredServerIp
if (-not [string]::IsNullOrWhiteSpace($manualIp)) {
    Write-Log "Trying manual/preferred server IP first: $manualIp"
}
if (-not [string]::IsNullOrWhiteSpace($knownServerIp)) {
    Write-Log "Last known ParqueRM server: $knownServerIp"
}

Write-Log 'Discovering ParqueRM server on the local network...'
$discovery = Invoke-Discovery $manualIp $knownServerIp
$result = $discovery.Result

if ($result.status -eq 'not_found') {
    Write-Log 'No ParqueRM server was discovered. Existing hosts/configuration were left untouched.' 'ERROR'
    exit 1
}

if ($result.status -eq 'conflict' -and $null -eq $result.selected) {
    Write-Log 'Multiple ParqueRM servers were discovered and none matched the last known server. Existing hosts/configuration were left untouched.' 'ERROR'
    if ($result.conflicts) {
        foreach ($conflict in @($result.conflicts)) {
            Write-Log "Conflict: $($conflict.ip) instance=$($conflict.instanceId) source=$($conflict.source)" 'WARN'
        }
    }
    exit 2
}

$selected = $result.selected
if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.ip)) {
    Write-Log 'Discovery completed without a usable selected server. Existing hosts/configuration were left untouched.' 'ERROR'
    exit 1
}

if ($result.status -eq 'conflict') {
    Write-Log 'Multiple ParqueRM servers were detected. Keeping the last known server because it still responds.' 'WARN'
}

$serverIp = ConvertTo-Ipv4Text ([string]$selected.ip)
if ([string]::IsNullOrWhiteSpace($serverIp)) {
    Write-Log "Selected server IP is invalid: $($selected.ip)" 'ERROR'
    exit 1
}

Write-Log "ParqueRM server selected: $serverIp instance=$($selected.instanceId) source=$($selected.source)"
Configure-Hosts $serverIp
Test-CanonicalUrl ([string]$selected.instanceId)

$clientConfig = [ordered]@{
    serverIp = $serverIp
    instanceId = [string]$selected.instanceId
    version = [string]$selected.version
    url = $canonicalUrl
    aliases = @('http://parque.rm.local')
    source = [string]$selected.source
    sources = @($selected.sources)
    lastStatus = [string]$result.status
    conflicts = @($result.conflicts)
    updatedAt = (Get-Date).ToString('s')
} | ConvertTo-Json -Depth 6
$clientConfig | Out-File -FilePath $configPath -Encoding utf8 -NoNewline

Write-Log "$canonicalUrl is ready on this client." 'INFO'
