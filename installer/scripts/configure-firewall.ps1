#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates Windows Firewall inbound rules for ParqueRM.

.PARAMETER EnableSqlServerPort
    If set, also opens TCP 1433 for LAN access to SQL Server.
    NOT recommended by default -- keep SQL Server internal.

.PARAMETER Remove
    If set, removes ParqueRM firewall rules instead of creating them.
#>
param(
    [switch]$EnableSqlServerPort,
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Rules = @(
    @{ Name = 'ParqueRM Frontend TCP 80';   Port = 80;   Always = $true  },
    @{ Name = 'ParqueRM Backend TCP 3000';  Port = 3000; Always = $true  },
    @{ Name = 'ParqueRM SQL Server TCP 1433'; Port = 1433; Always = $false }
)

foreach ($rule in $Rules) {
    $shouldApply = $rule.Always -or ($rule.Port -eq 1433 -and $EnableSqlServerPort)

    if ($Remove) {
        if (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $rule.Name
            Write-Host "  [REMOVED] $($rule.Name)" -ForegroundColor Yellow
        } else {
            Write-Host "  [SKIP] $($rule.Name) -- not found" -ForegroundColor Gray
        }
        continue
    }

    if (-not $shouldApply) { continue }

    if (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue) {
        Write-Host "  [EXISTS] $($rule.Name)" -ForegroundColor Gray
        continue
    }

    New-NetFirewallRule `
        -DisplayName $rule.Name `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $rule.Port `
        -Action Allow `
        -Profile Any `
        -Description "ParqueRM -- allows LAN access on port $($rule.Port)" | Out-Null

    Write-Host "  [CREATED] $($rule.Name) -- TCP $($rule.Port)" -ForegroundColor Green
}

if (-not $Remove) {
    Write-Host ""
    Write-Host "Firewall rules configured." -ForegroundColor Cyan
    if (-not $EnableSqlServerPort) {
        Write-Host "  NOTE: SQL Server port 1433 is NOT exposed to LAN (recommended)." -ForegroundColor Yellow
    }
}
