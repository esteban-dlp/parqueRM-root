#Requires -Version 5.1
<#
.SYNOPSIS
    Writes SEED_DEMO_DATA into parqueRM-root\.env.

.DESCRIPTION
    Lets the installer choose whether the db-init container loads
    07_seed_demo_data.sql (sample visitantes/vehiculos/hospedaje/recibos).
    Roles, permissions, the admin user, catalogs and park config always run
    regardless of this value.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('true', 'false')]
    [string]$Value,
    [string]$EnvPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvPath)) {
    $EnvPath = Join-Path $PSScriptRoot '..\.env'
}

$envDir = Split-Path $EnvPath -Parent
if (-not (Test-Path $envDir)) { New-Item -ItemType Directory -Path $envDir -Force | Out-Null }

$lines = @()
if (Test-Path $EnvPath) {
    $lines = @(Get-Content $EnvPath)
}

$updated = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^SEED_DEMO_DATA=') {
        $lines[$i] = "SEED_DEMO_DATA=$Value"
        $updated = $true
        break
    }
}

if (-not $updated) {
    if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[-1])) {
        $lines += ''
    }
    $lines += "SEED_DEMO_DATA=$Value"
}

$lines | Set-Content -Path $EnvPath -Encoding utf8
Write-Host "SEED_DEMO_DATA=$Value"
