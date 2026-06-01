#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Ejecuta al arrancar Windows: verifica la IP actual, actualiza la config si cambio,
    y se asegura de que los servicios de ParqueRM esten corriendo.

.PARAMETER InstallDir
    Directorio raiz de instalacion. Default: C:\ParqueRM
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

Write-Log "=== ParqueRM startup check ==="

# --- Leer IP guardada en config -----------------------------------------------
$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
if (-not (Test-Path $configPath)) {
    Write-Log "Config no encontrada en $configPath. Saltando actualizacion de IP." 'WARN'
} else {
    try {
        $cfg      = Get-Content $configPath -Raw | ConvertFrom-Json
        $savedIp  = $cfg.serverIp
    } catch {
        Write-Log "Error leyendo config: $_" 'ERROR'
        $savedIp = ''
    }

    # --- Detectar IP LAN actual -----------------------------------------------
    $currentIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback' -and
            $_.InterfaceAlias -notmatch 'VirtualBox' -and
            $_.InterfaceAlias -notmatch 'VMware' -and
            $_.IPAddress -notlike '169.*' -and
            $_.IPAddress -ne '127.0.0.1'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress

    if (-not $currentIp) {
        Write-Log "No se pudo detectar IP LAN. Red no disponible aun." 'WARN'
    } elseif ($savedIp -eq $currentIp) {
        Write-Log "IP sin cambios ($currentIp)."
    } else {
        Write-Log "IP cambio de '$savedIp' a '$currentIp'. Actualizando configuracion..." 'WARN'

        $envPath   = Join-Path $InstallDir 'app\backend\.env'
        $genScript = Join-Path $InstallDir 'tools\installer-scripts\generate-config.ps1'

        if (-not (Test-Path $genScript)) {
            Write-Log "generate-config.ps1 no encontrado en $genScript. No se puede actualizar IP." 'ERROR'
        } else {
            # Leer DbPassword del .env existente
            function Read-EnvVal([string]$path, [string]$key) {
                if (-not (Test-Path $path)) { return '' }
                $line = (Get-Content $path | Where-Object { $_ -match "^$([regex]::Escape($key))=" } | Select-Object -First 1)
                if (-not $line) { return '' }
                $val = ($line -split '=', 2)[1]
                if ($val.Length -ge 2 -and $val[0] -eq '"' -and $val[-1] -eq '"') {
                    $val = $val.Substring(1, $val.Length - 2)
                }
                return $val
            }

            $dbPassword = Read-EnvVal $envPath 'DB_PASSWORD'
            if (-not $dbPassword) {
                Write-Log "No se pudo leer DB_PASSWORD del .env. No se puede actualizar IP." 'ERROR'
            } else {
                try {
                    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $genScript `
                        -InstallDir $InstallDir `
                        -ServerIp $currentIp `
                        -DbPassword $dbPassword `
                        -PreserveExistingSecrets
                    if ($LASTEXITCODE -ne 0) {
                        throw "generate-config.ps1 failed with exit code $LASTEXITCODE"
                    }
                    Write-Log "Configuracion actualizada para IP $currentIp."
                } catch {
                    Write-Log "Error actualizando config: $_" 'ERROR'
                }
            }
        }
    }
}

# --- Asegurar que los servicios esten corriendo --------------------------------
foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "Servicio $svcName no encontrado (no instalado)." 'WARN'
        continue
    }
    if ($svc.Status -ne 'Running') {
        Write-Log "Servicio $svcName detenido. Intentando iniciar..." 'WARN'
        try {
            Start-Service -Name $svcName -ErrorAction Stop
            Start-Sleep -Seconds 5
            $svc.Refresh()
            if ($svc.Status -eq 'Running') {
                Write-Log "Servicio $svcName iniciado correctamente."
            } else {
                Write-Log "Servicio $svcName no respondio al inicio. Estado: $($svc.Status)" 'ERROR'
            }
        } catch {
            Write-Log "Error iniciando ${svcName}: $_" 'ERROR'
        }
    } else {
        Write-Log "Servicio $svcName corriendo OK."
    }
}

Write-Log "=== Fin del startup check ==="
