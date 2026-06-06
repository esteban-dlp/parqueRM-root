#Requires -RunAsAdministrator
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [switch]$DropDatabase,
    [switch]$DeleteBackups
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "ParqueRM - limpieza para reinstalacion" -ForegroundColor Cyan
Write-Host "InstallDir: $InstallDir"
Write-Host ""

# 1. Stop services
Write-Host "Deteniendo servicios..." -ForegroundColor Cyan
foreach ($svcName in @('ParqueRMFrontend', 'ParqueRMBackend')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
        Write-Host "  Stop $svcName"
        Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
    }
}

Start-Sleep -Seconds 3

# 2. Kill ParqueRM-owned processes only
Write-Host "Cerrando procesos de ParqueRM..." -ForegroundColor Cyan
$resolvedInstall = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$prefix = $resolvedInstall + '\'

$targetNames = @(
    'node.exe',
    'caddy.exe',
    'ParqueRMBackend.exe',
    'ParqueRMFrontend.exe'
)

$procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -in $targetNames -and (
            ($_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) -or
            ($_.CommandLine -and $_.CommandLine.IndexOf($prefix, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        )
    }

foreach ($p in $procs) {
    Write-Host "  Kill $($p.Name) PID $($p.ProcessId)"
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

# 3. Remove services
Write-Host "Eliminando servicios..." -ForegroundColor Cyan
foreach ($svcName in @('ParqueRMFrontend', 'ParqueRMBackend')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        sc.exe delete $svcName | Out-Null
        Write-Host "  Eliminado $svcName"
    }
}

# 4. Remove startup task
Write-Host "Eliminando tarea programada..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName 'ParqueRM_IpCheck' -Confirm:$false -ErrorAction SilentlyContinue

# 5. Remove firewall rules
Write-Host "Eliminando reglas firewall..." -ForegroundColor Cyan
Get-NetFirewallRule -DisplayName '*ParqueRM*' -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

# 6. Optionally drop DB
if ($DropDatabase) {
    Write-Host "Eliminando base de datos ParqueRM..." -ForegroundColor Yellow

    $sqlcmd = ''
    $candidates = @(
        "$InstallDir\runtime\sqlcmd\sqlcmd.exe",
        'C:\Program Files\SqlCmd\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $sqlcmd = $candidate
            break
        }
    }

    if (-not $sqlcmd) {
        $cmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
        if ($cmd) { $sqlcmd = $cmd.Source }
    }

    if ($sqlcmd) {
        $sql = "IF DB_ID(N'ParqueRM') IS NOT NULL BEGIN ALTER DATABASE [ParqueRM] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [ParqueRM]; END"
        & $sqlcmd -S '127.0.0.1,1433' -E -Q $sql -b
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Base ParqueRM eliminada"
        } else {
            Write-Host "  No se pudo eliminar con Windows Auth. Si usa sa, eliminela manualmente." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  sqlcmd no encontrado. Base no eliminada." -ForegroundColor Yellow
    }
}

# 7. Delete install folder safely
Write-Host "Eliminando carpeta de instalacion..." -ForegroundColor Cyan

$full = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
if ($full -ne 'C:\ParqueRM') {
    throw "Ruta inesperada: $full. Por seguridad solo se elimina C:\ParqueRM."
}

if (Test-Path $full) {
    if (-not $DeleteBackups -and (Test-Path "$full\backups")) {
        $backupTarget = "C:\ParqueRM-backups-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Move-Item -LiteralPath "$full\backups" -Destination $backupTarget -Force
        Write-Host "  Backups preservados en: $backupTarget" -ForegroundColor Yellow
    }

    Remove-Item -LiteralPath $full -Recurse -Force
    Write-Host "  Carpeta eliminada: $full"
}

Write-Host ""
Write-Host "Limpieza terminada. Ya puedes reinstalar desde cero." -ForegroundColor Green