#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registra la tarea de inicio de Windows que verifica y actualiza la IP de ParqueRM.

.PARAMETER InstallDir
    Directorio raiz de instalacion. Default: C:\ParqueRM
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

$ErrorActionPreference = 'Stop'

$taskName   = 'ParqueRM_IpCheck'
$scriptPath = Join-Path $InstallDir 'tools\installer-scripts\check-ip-on-startup.ps1'

$action  = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""

# Disparar al iniciar el sistema, con 30 segundos de delay para que la red levante
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT30S'

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false

# Correr como SYSTEM con privilegios maximos (no requiere contrasena de usuario)
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Eliminar tarea anterior si existe
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  Tarea anterior '$taskName' eliminada." -ForegroundColor Yellow
}

Register-ScheduledTask `
    -TaskName  $taskName `
    -Action    $action `
    -Trigger   $trigger `
    -Settings  $settings `
    -Principal $principal `
    -Description 'Verifica la IP del servidor al arrancar y actualiza la configuracion de ParqueRM si cambio.' `
    | Out-Null

Write-Host "  [OK] Tarea '$taskName' registrada. Se ejecuta 30 segundos despues de cada inicio del sistema." -ForegroundColor Green
