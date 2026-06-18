#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures stable local hostnames for ParqueRM on this Windows machine.

.DESCRIPTION
    Adds/refreshes hosts entries for the canonical local URL and legacy
    aliases. The server maps them to 127.0.0.1; client-only fallback mode maps
    them to the discovered LAN IP.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string[]]$HostNames = @('parquerm.local', 'parque.rm.local', 'parque.rm.home.arpa'),
    [string]$TargetIp = '127.0.0.1',
    [switch]$Remove
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

function Test-LocalHostsEntries([string]$Path, [string[]]$Names, [string]$ExpectedIp) {
    if (-not (Test-Path $Path)) { return $false }

    $mappedNames = @()
    foreach ($line in @(Get-Content -Path $Path -ErrorAction Stop)) {
        $content = ($line -split '#', 2)[0].Trim()
        if ([string]::IsNullOrWhiteSpace($content)) { continue }

        $tokens = @($content -split '\s+' | Where-Object { $_ })
        if ($tokens.Count -lt 2 -or $tokens[0] -ne $ExpectedIp) { continue }
        $mappedNames += @($tokens | Select-Object -Skip 1 | ForEach-Object { $_.ToLowerInvariant() })
    }

    foreach ($name in $Names) {
        if ($mappedNames -notcontains $name.ToLowerInvariant()) { return $false }
    }
    return $true
}

function Set-LocalHostsEntries([string[]]$Names, [string]$IpAddress, [bool]$RemoveEntries) {
    $cleanNames = @($Names |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Select-Object -Unique)

    if ($cleanNames.Count -eq 0) {
        throw 'No hostnames were provided.'
    }
    if (-not $RemoveEntries) {
        $parsedIp = $null
        if (-not [System.Net.IPAddress]::TryParse($IpAddress, [ref]$parsedIp) -or
            $parsedIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
            throw "TargetIp must be a valid IPv4 address: $IpAddress"
        }
        $IpAddress = $parsedIp.IPAddressToString
    }

    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $hostsDir = Split-Path $hostsPath -Parent
    $marker = '# ParqueRM local URL'
    $escapedNames = (($cleanNames | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $hostPattern = "(?i)(^|\s)($escapedNames)(\s|$)"
    $temporaryPath = Join-Path $hostsDir "hosts.parquerm.$([guid]::NewGuid().ToString('N')).tmp"
    $backupPath = Join-Path $hostsDir "hosts.parquerm.$([guid]::NewGuid().ToString('N')).bak"
    $originalAttributes = $null
    $hostsAcl = $null

    $lines = @()
    if (Test-Path $hostsPath) {
        $lines = @(Get-Content -Path $hostsPath -ErrorAction Stop)
        $originalAttributes = [System.IO.File]::GetAttributes($hostsPath)
        $hostsAcl = Get-Acl -Path $hostsPath -ErrorAction Stop
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

    $newLines = @($kept)
    if (-not $RemoveEntries) {
        $newLine = "$IpAddress`t$($cleanNames -join ' ') $marker"
        $newLines += $newLine
    }

    try {
        [System.IO.File]::WriteAllLines(
            $temporaryPath,
            [string[]]$newLines,
            [System.Text.Encoding]::ASCII)

        if ($hostsAcl) {
            Set-Acl -Path $temporaryPath -AclObject $hostsAcl -ErrorAction Stop
        }

        if (Test-Path $hostsPath) {
            if (($originalAttributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
                [System.IO.File]::SetAttributes(
                    $hostsPath,
                    ($originalAttributes -bxor [System.IO.FileAttributes]::ReadOnly))
            }
            [System.IO.File]::Replace($temporaryPath, $hostsPath, $backupPath, $true)
        } else {
            Move-Item -LiteralPath $temporaryPath -Destination $hostsPath -Force
        }

        if (-not $RemoveEntries -and -not (Test-LocalHostsEntries $hostsPath $cleanNames $IpAddress)) {
            throw 'The hosts file was written, but the required mappings could not be verified.'
        }

        if ($null -ne $originalAttributes) {
            [System.IO.File]::SetAttributes($hostsPath, $originalAttributes)
        }
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    } catch {
        if (Test-Path $backupPath) {
            Copy-Item -LiteralPath $backupPath -Destination $hostsPath -Force -ErrorAction SilentlyContinue
        }
        if ($null -ne $originalAttributes -and (Test-Path $hostsPath)) {
            [System.IO.File]::SetAttributes($hostsPath, $originalAttributes)
        }
        throw
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }

    $clearDnsCache = Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue
    if ($clearDnsCache) {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    } else {
        & ipconfig /flushdns | Out-Null
    }

    return $cleanNames
}

if ($Remove) {
    Write-Log 'Removing ParqueRM local hostnames...' 'Cyan'
    $removedNames = Set-LocalHostsEntries $HostNames $TargetIp $true
    Write-Log "hosts entries removed: $($removedNames -join ', ')" 'Green'
    exit 0
}

Write-Log "Configuring ParqueRM local hostnames for $TargetIp..." 'Cyan'
$configuredNames = Set-LocalHostsEntries $HostNames $TargetIp $false
Write-Log "hosts configured: $TargetIp -> $($configuredNames -join ', ')" 'Green'

foreach ($name in $configuredNames) {
    $resolved = @()
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            $resolved = @([System.Net.Dns]::GetHostAddresses($name) |
                Where-Object {
                    $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
                    $_.IPAddressToString -eq $TargetIp
                } |
                ForEach-Object { $_.IPAddressToString })
        } catch {
            $resolved = @()
        }
        if ($resolved.Count -gt 0) { break }
        Start-Sleep -Seconds 1
    }

    if ($resolved.Count -eq 0) {
        throw "$name does not resolve to $TargetIp after updating the hosts file."
    }
    Write-Log "$name resolves to: $($resolved -join ', ')" 'Green'
}

Write-Log 'Local hostname configuration complete.' 'Cyan'
