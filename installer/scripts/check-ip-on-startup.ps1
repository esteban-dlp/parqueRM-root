#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Runs at Windows startup to keep ParqueRM local URL support healthy.

.DESCRIPTION
    Refreshes local hosts entries, logs current IPv4 addresses, and makes sure
    ParqueRM services are running. It intentionally does not read or rewrite
    database/JWT secrets.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

$ErrorActionPreference = 'Stop'

$logDir  = Join-Path $InstallDir 'logs'
$logFile = Join-Path $logDir 'startup-check.log'

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log([string]$msg, [string]$level = 'INFO') {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$level] $msg"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

function Get-CurrentIpv4Addresses {
    @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.InterfaceAlias -notmatch 'Loopback|VirtualBox|VMware|vEthernet|WSL|Bluetooth|Tunnel'
        } |
        Select-Object -ExpandProperty IPAddress -Unique)
}

Write-Log '=== ParqueRM startup check ==='

$configureLocalName = Join-Path $InstallDir 'tools\installer-scripts\configure-local-name.ps1'
if (Test-Path $configureLocalName) {
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $configureLocalName -InstallDir $InstallDir
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'Local URL hosts entries refreshed.'
        } else {
            Write-Log "configure-local-name.ps1 exited with code $LASTEXITCODE." 'ERROR'
        }
    } catch {
        Write-Log "Error refreshing local URL hosts entries: $_" 'ERROR'
    }
} else {
    Write-Log "configure-local-name.ps1 not found at $configureLocalName." 'WARN'
}

$currentIps = @(Get-CurrentIpv4Addresses)
if ($currentIps.Count -gt 0) {
    Write-Log "Current IPv4 addresses: $($currentIps -join ', ')"
} else {
    Write-Log 'No LAN IPv4 address detected yet.' 'WARN'
}

foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend', 'ParqueRMLocalName')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "Service $svcName not found." 'WARN'
        continue
    }
    if ($svc.Status -ne 'Running') {
        Write-Log "Service $svcName is stopped. Attempting start..." 'WARN'
        try {
            Start-Service -Name $svcName -ErrorAction Stop
            Start-Sleep -Seconds 5
            $svc.Refresh()
            if ($svc.Status -eq 'Running') {
                Write-Log "Service $svcName started successfully."
            } else {
                Write-Log "Service $svcName did not report Running. Status: $($svc.Status)" 'ERROR'
            }
        } catch {
            Write-Log "Error starting ${svcName}: $_" 'ERROR'
        }
    } else {
        Write-Log "Service $svcName running OK."
    }
}

Write-Log '=== End startup check ==='
