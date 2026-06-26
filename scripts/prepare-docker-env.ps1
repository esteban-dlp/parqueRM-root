#Requires -Version 5.1
<#
.SYNOPSIS
    Detects the LAN IP and writes SYSTEM_LAN_URL into parqueRM-root\.env.

.DESCRIPTION
    Docker itself cannot reliably know the host LAN IP from inside the db-init
    container, so Windows helper scripts run this before docker compose up.
    If no LAN IP is found, the script falls back to http://192.168.1.10.
#>
param(
    [string]$EnvPath = '',
    [string]$FallbackUrl = 'http://192.168.1.10',
    [string]$FrontendPort = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvPath)) {
    $EnvPath = Join-Path $PSScriptRoot '..\.env'
}

$VirtualPatterns = @(
    'vEthernet',
    'VMware',
    'VirtualBox',
    'Hyper-V',
    'WSL',
    'Loopback',
    'Pseudo',
    'Bluetooth',
    'Teredo',
    'ISATAP',
    'Microsoft Wi-Fi Direct',
    'WAN Miniport',
    'Tunnel'
)

function Test-IsVirtual([string]$Name) {
    foreach ($pattern in $VirtualPatterns) {
        if ($Name -like "*$pattern*") { return $true }
    }
    return $false
}

function Get-LanIp {
    $candidates = @()
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PrefixOrigin -ne 'WellKnown' -and
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.SuffixOrigin -ne 'Random'
        }

    foreach ($addr in $addresses) {
        $adapter = Get-NetAdapter -InterfaceIndex $addr.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $adapter) { continue }
        if ($adapter.Status -ne 'Up') { continue }
        if (Test-IsVirtual $adapter.Name) { continue }
        if (Test-IsVirtual $adapter.InterfaceDescription) { continue }

        $candidates += [PSCustomObject]@{
            IP = $addr.IPAddress
            Name = "$($adapter.Name) $($adapter.InterfaceDescription)"
        }
    }

    if ($candidates.Count -eq 0) { return '' }

    $wired = $candidates | Where-Object { $_.Name -notmatch 'Wi-Fi|Wireless|802\.11|WLAN' } | Select-Object -First 1
    if ($wired) { return $wired.IP }

    return $candidates[0].IP
}

$envDir = Split-Path $EnvPath -Parent
if (-not (Test-Path $envDir)) { New-Item -ItemType Directory -Path $envDir -Force | Out-Null }

$lines = @()
if (Test-Path $EnvPath) {
    $lines = @(Get-Content $EnvPath)
}

function Get-EnvLineValue([string]$Name) {
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($Name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return ''
}

function Add-PortIfNeeded([string]$Url, [string]$Port) {
    $cleanUrl = $Url.TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($Port)) { return $cleanUrl }
    if ($Port -eq '80' -or $Port -eq '443') { return $cleanUrl }

    $portNumber = 0
    if (-not [int]::TryParse($Port, [ref]$portNumber)) { return $cleanUrl }
    if ($portNumber -le 0) { return $cleanUrl }

    try {
        $uri = [uri]$cleanUrl
        if (-not $uri.IsDefaultPort) { return $cleanUrl }
        $builder = [System.UriBuilder]::new($uri)
        $builder.Port = $portNumber
        return $builder.Uri.AbsoluteUri.TrimEnd('/')
    } catch {
        return $cleanUrl
    }
}

$resolvedFrontendPort = if ([string]::IsNullOrWhiteSpace($FrontendPort)) { Get-EnvLineValue 'FRONTEND_PORT' } else { $FrontendPort }
if ([string]::IsNullOrWhiteSpace($resolvedFrontendPort)) { $resolvedFrontendPort = '8080' }

$ip = Get-LanIp
$baseSystemLanUrl = if ([string]::IsNullOrWhiteSpace($ip)) { $FallbackUrl } else { "http://$ip" }
$systemLanUrl = Add-PortIfNeeded $baseSystemLanUrl $resolvedFrontendPort

$updated = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^SYSTEM_LAN_URL=') {
        $lines[$i] = "SYSTEM_LAN_URL=$systemLanUrl"
        $updated = $true
        break
    }
}

if (-not $updated) {
    if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[-1])) {
        $lines += ''
    }
    $lines += "SYSTEM_LAN_URL=$systemLanUrl"
}

$lines | Set-Content -Path $EnvPath -Encoding utf8
Write-Host "SYSTEM_LAN_URL=$systemLanUrl"
