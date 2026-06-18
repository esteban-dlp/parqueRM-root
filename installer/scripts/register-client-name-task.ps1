#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers automatic ParqueRM name refresh for a Windows client.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'ParqueRM_ClientNameRefresh'
$scriptPath = Join-Path $InstallDir 'tools\installer-scripts\refresh-client-local-name.ps1'
if (-not (Test-Path $scriptPath)) { throw "Client refresh script not found: $scriptPath" }

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -InstallDir `"$InstallDir`""

$startupTrigger = New-ScheduledTaskTrigger -AtStartup
$startupTrigger.Delay = 'PT20S'
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$logonTrigger.Delay = 'PT15S'
$repeatTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At ((Get-Date).AddMinutes(2)) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -RunOnlyIfNetworkAvailable:$false

$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger @($startupTrigger, $logonTrigger, $repeatTrigger) `
    -Settings $settings `
    -Principal $principal `
    -Description 'Discovers ParqueRM and keeps parquerm.local mapped to the current LAN server IP.' |
    Out-Null

Write-Host "  [OK] Task '$taskName' registered." -ForegroundColor Green
