#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures stable local hostnames for ParqueRM on this Windows machine.

.DESCRIPTION
    Adds/refreshes hosts entries that make http://parque.rm.local and aliases
    resolve to 127.0.0.1 on the installed server. LAN discovery is handled by
    local-name-responder.ps1 through mDNS when client machines support it.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string[]]$HostNames = @('parque.rm.local', 'parquerm.local')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = Join-Path $InstallDir 'logs\network'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'local-name-config.log'

function Write-Log([string]$Message, [string]$Color = 'White') {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line -ForegroundColor $Color
}

function Set-LocalHostsEntries([string[]]$Names) {
    $cleanNames = @($Names |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Select-Object -Unique)

    if ($cleanNames.Count -eq 0) {
        throw 'No hostnames were provided.'
    }

    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $marker = '# ParqueRM local URL'
    $escapedNames = (($cleanNames | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $hostPattern = "(?i)(^|\s)($escapedNames)(\s|$)"

    $lines = @()
    if (Test-Path $hostsPath) {
        $lines = @(Get-Content -Path $hostsPath -ErrorAction Stop)
    }

    $kept = @()
    foreach ($line in $lines) {
        if ($line -match [regex]::Escape($marker)) { continue }
        if ($line.TrimStart().StartsWith('#')) {
            $kept += $line
            continue
        }
        if ($line -match $hostPattern) { continue }
        $kept += $line
    }

    $newLine = "127.0.0.1`t$($cleanNames -join ' ') $marker"
    Set-Content -Path $hostsPath -Value @($kept + $newLine) -Encoding ASCII -Force
    return $cleanNames
}

Write-Log 'Configuring ParqueRM local hostnames...' 'Cyan'
$configuredNames = Set-LocalHostsEntries $HostNames
Write-Log "hosts configured: 127.0.0.1 -> $($configuredNames -join ', ')" 'Green'

foreach ($name in $configuredNames) {
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($name) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.IPAddressToString }
        if ($resolved) {
            Write-Log "$name resolves to: $($resolved -join ', ')" 'Green'
        } else {
            Write-Log "$name did not resolve to an IPv4 address yet." 'Yellow'
        }
    } catch {
        Write-Log "$name resolution failed: $($_.Exception.Message)" 'Yellow'
    }
}

Write-Log 'Local hostname configuration complete.' 'Cyan'
