#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates Windows Firewall inbound rules for ParqueRM.

.PARAMETER EnableSqlServerPort
    If set, also opens TCP 1433 for LAN access to SQL Server.
    NOT recommended by default -- keep SQL Server internal.

.PARAMETER EnableBackendPort
    If set, also opens TCP 3000 for direct backend access.
    NOT recommended by default -- Caddy should be the single public entry point.

.PARAMETER Remove
    If set, removes ParqueRM firewall rules instead of creating them.
#>
param(
    [switch]$EnableBackendPort,
    [switch]$EnableSqlServerPort,
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Rules = @(
    @{ Name = 'ParqueRM Caddy TCP 80';      Protocol = 'TCP'; Port = 80;   Always = $true;  Switch = '' },
    @{ Name = 'ParqueRM mDNS UDP 5353';     Protocol = 'UDP'; Port = 5353; Always = $true;  Switch = '' },
    @{ Name = 'ParqueRM Backend TCP 3000';  Protocol = 'TCP'; Port = 3000; Always = $false; Switch = 'backend' },
    @{ Name = 'ParqueRM SQL Server TCP 1433'; Protocol = 'TCP'; Port = 1433; Always = $false; Switch = 'sql' }
)
$LegacyRuleNames = @('ParqueRM Frontend TCP 80')

foreach ($legacyName in $LegacyRuleNames) {
    $legacyRule = Get-NetFirewallRule -DisplayName $legacyName -ErrorAction SilentlyContinue
    if (-not $legacyRule) { continue }

    Remove-NetFirewallRule -DisplayName $legacyName
    if ($Remove) {
        Write-Host "  [REMOVED] $legacyName" -ForegroundColor Yellow
    } else {
        Write-Host "  [REMOVED] Legacy firewall rule: $legacyName" -ForegroundColor Yellow
    }
}

foreach ($rule in $Rules) {
    $shouldApply = $rule.Always -or
        ($rule.Switch -eq 'backend' -and $EnableBackendPort) -or
        ($rule.Switch -eq 'sql' -and $EnableSqlServerPort)

    if ($Remove) {
        if (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $rule.Name
            Write-Host "  [REMOVED] $($rule.Name)" -ForegroundColor Yellow
        } else {
            Write-Host "  [SKIP] $($rule.Name) -- not found" -ForegroundColor Gray
        }
        continue
    }

    if (-not $shouldApply) {
        if (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $rule.Name
            Write-Host "  [REMOVED] $($rule.Name) -- not enabled for this install" -ForegroundColor Yellow
        }
        continue
    }

    if (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue) {
        Write-Host "  [EXISTS] $($rule.Name)" -ForegroundColor Gray
        continue
    }

    New-NetFirewallRule `
        -DisplayName $rule.Name `
        -Direction Inbound `
        -Protocol $rule.Protocol `
        -LocalPort $rule.Port `
        -Action Allow `
        -Profile Any `
        -Description "ParqueRM -- allows LAN access on $($rule.Protocol) port $($rule.Port)" | Out-Null

    Write-Host "  [CREATED] $($rule.Name) -- $($rule.Protocol) $($rule.Port)" -ForegroundColor Green
}

if (-not $Remove) {
    Write-Host ""
    Write-Host "Firewall rules configured." -ForegroundColor Cyan
    if (-not $EnableBackendPort) {
        Write-Host "  NOTE: Backend port 3000 is NOT exposed to LAN; use http://parque.rm.local/api through Caddy." -ForegroundColor Yellow
    }
    if (-not $EnableSqlServerPort) {
        Write-Host "  NOTE: SQL Server port 1433 is NOT exposed to LAN (recommended)." -ForegroundColor Yellow
    }
}
