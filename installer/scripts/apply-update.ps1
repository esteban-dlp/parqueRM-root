#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies a ParqueRM update package to an existing installation.

.DESCRIPTION
    1. Reads existing config from C:\ParqueRM\config\parquerm.config.json
    2. Backs up the database before any changes
    3. Stops ParqueRM services
    4. Copies new backend files (preserves existing .env)
    5. Copies new frontend files (preserves existing config.json)
    6. Runs pending DB migrations
    7. Restarts services
    8. Shows final URLs

.PARAMETER UpdatePackageDir
    Directory containing the extracted update package (the ParqueRM-Update folder).
    If not set, looks for it next to this script.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM

.PARAMETER DbPassword
    SQL Server SA password. Read from config if not supplied.
#>
param(
    [string]$UpdatePackageDir = '',
    [string]$InstallDir       = 'C:\ParqueRM',
    [string]$DbPassword       = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# --- Resolve update package dir -----------------------------------------------
if ([string]::IsNullOrWhiteSpace($UpdatePackageDir)) {
    $UpdatePackageDir = Join-Path $ScriptDir '..'
}
$UpdatePackageDir = (Resolve-Path $UpdatePackageDir).Path

# --- Paths --------------------------------------------------------------------
$ConfigFile     = Join-Path $InstallDir 'config\parquerm.config.json'
$BackendDotEnv  = Join-Path $InstallDir 'app\backend\.env'
$FrontendConfig = Join-Path $InstallDir 'app\frontend\dist\config.json'
$LogDir         = Join-Path $InstallDir 'logs\updates'
$BackupDir      = Join-Path $InstallDir 'backups'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogDir "update-$Timestamp.log"

function Write-Log([string]$msg, [string]$color = 'White') {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Abort([string]$msg) {
    Write-Log "ABORT: $msg" 'Red'
    Write-Log "" 'Red'
    Write-Log "Manual recovery:" 'Yellow'
    Write-Log "  1. Check log: $LogFile" 'Yellow'
    Write-Log "  2. If services are stopped, restart them manually:" 'Yellow'
    Write-Log "     Start-Service ParqueRMBackend; Start-Service ParqueRMFrontend" 'Yellow'
    Write-Log "  3. If DB backup exists, restore it from: $BackupDir" 'Yellow'
    exit 1
}

Write-Log "=== ParqueRM Update started at $Timestamp ===" 'Cyan'
Write-Log "Update source: $UpdatePackageDir" 'Gray'
Write-Log "Install dir  : $InstallDir" 'Gray'

# --- Step 1: Read config ------------------------------------------------------
Write-Log "--- Step 1: Reading configuration ---" 'Cyan'
if (-not (Test-Path $ConfigFile)) { Abort "Config not found: $ConfigFile" }

$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$DbName = if ($cfg.dbName) { $cfg.dbName } else { 'ParqueRM' }
$DbUser = if ($cfg.dbUser) { $cfg.dbUser } else { 'sa' }

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    # Try to read from backend .env
    if (Test-Path $BackendDotEnv) {
        $envContent = Get-Content $BackendDotEnv
        $pwLine = $envContent | Where-Object { $_ -match '^DB_PASSWORD=' }
        if ($pwLine) { $DbPassword = ($pwLine -split '=', 2)[1] }
    }
}
if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    $DbPassword = Read-Host -Prompt "Enter SQL Server SA password"
}
Write-Log "Config loaded. DB: $DbName, Server: $($cfg.serverIp)" 'Green'

# --- Step 2: Backup database --------------------------------------------------
Write-Log "--- Step 2: Database backup ---" 'Cyan'
$backupFile = Join-Path $BackupDir "ParqueRM-backup-$Timestamp.bak"
$sqlcmdCmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
$sqlcmd = if ($sqlcmdCmd) { $sqlcmdCmd.Source } else { $null }
if (-not $sqlcmd) {
    $candidates = @(
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe'
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $sqlcmd = $c; break } }
}
if ($sqlcmd) {
    $backupSql = "BACKUP DATABASE [$DbName] TO DISK='$backupFile' WITH FORMAT, INIT, NAME='ParqueRM Pre-Update Backup'"
    & $sqlcmd -S 'localhost,1433' -U $DbUser -P $DbPassword -Q $backupSql -b
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Database backed up to: $backupFile" 'Green'
    } else {
        Write-Log "WARNING: Database backup failed. Continuing but proceed with caution." 'Yellow'
    }
} else {
    Write-Log "WARNING: sqlcmd not found -- skipping DB backup." 'Yellow'
}

# --- Step 3: Stop services ----------------------------------------------------
Write-Log "--- Step 3: Stopping services ---" 'Cyan'
foreach ($svcName in @('ParqueRMFrontend', 'ParqueRMBackend')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Stop-Service -Name $svcName -Force
        Write-Log "  Stopped $svcName" 'Yellow'
    }
}
Start-Sleep -Seconds 3

# --- Step 4: Copy backend (preserve .env) -------------------------------------
Write-Log "--- Step 4: Updating backend ---" 'Cyan'
$srcBackend = Join-Path $UpdatePackageDir 'backend'
$dstBackend = Join-Path $InstallDir 'app\backend'

if (-not (Test-Path $srcBackend)) { Abort "Backend update folder not found: $srcBackend" }

# Backup existing .env
$envBackup = $null
if (Test-Path $BackendDotEnv) {
    $envBackup = Get-Content $BackendDotEnv -Raw
}

# Copy new files
robocopy $srcBackend $dstBackend /E /NFL /NDL /NJH /NJS /MIR /XF '.env' /XD 'node_modules' | Out-Null
Write-Log "  Backend files updated (node_modules preserved)" 'Green'

# If update package includes node_modules, copy them
$srcNodeModules = Join-Path $srcBackend 'node_modules'
if (Test-Path $srcNodeModules) {
    Write-Log "  Update includes node_modules -- copying (this takes a few minutes) ..." 'Yellow'
    robocopy $srcNodeModules (Join-Path $dstBackend 'node_modules') /E /NFL /NDL /NJH /NJS /MIR | Out-Null
    Write-Log "  [OK] node_modules updated" 'Green'
}

# Restore .env
if ($envBackup) {
    $envBackup | Out-File -FilePath $BackendDotEnv -Encoding utf8 -NoNewline
    Write-Log "  Preserved existing .env" 'Green'
}

# --- Step 5: Copy frontend (preserve config.json) -----------------------------
Write-Log "--- Step 5: Updating frontend ---" 'Cyan'
$srcFrontend = Join-Path $UpdatePackageDir 'frontend'
$dstFrontend = Join-Path $InstallDir 'app\frontend\dist'

if (-not (Test-Path $srcFrontend)) { Abort "Frontend update folder not found: $srcFrontend" }

# Backup existing config.json
$configJsonBackup = $null
if (Test-Path $FrontendConfig) {
    $configJsonBackup = Get-Content $FrontendConfig -Raw
}

robocopy $srcFrontend $dstFrontend /E /NFL /NDL /NJH /NJS /MIR /XF 'config.json' | Out-Null
Write-Log "  Frontend files updated" 'Green'

# Restore config.json
if ($configJsonBackup) {
    $configJsonBackup | Out-File -FilePath $FrontendConfig -Encoding utf8 -NoNewline
    Write-Log "  Preserved existing config.json" 'Green'
} elseif (Test-Path (Join-Path $UpdatePackageDir 'frontend\config.json')) {
    Copy-Item (Join-Path $UpdatePackageDir 'frontend\config.json') $FrontendConfig -Force
}

# --- Step 6: Run migrations ---------------------------------------------------
Write-Log "--- Step 6: Database migrations ---" 'Cyan'
$migrationsDir = Join-Path $UpdatePackageDir 'database\migrations'
if (Test-Path $migrationsDir) {
    $migrateScript = Join-Path $InstallDir 'tools\installer-scripts\run-migrations.ps1'
    if (-not (Test-Path $migrateScript)) {
        # Fallback: use script next to this one
        $migrateScript = Join-Path $UpdatePackageDir 'scripts\run-migrations.ps1'
    }
    if (Test-Path $migrateScript) {
        & $migrateScript -DbPassword $DbPassword -DbName $DbName -MigrationsDir $migrationsDir
        if ($LASTEXITCODE -ne 0) { Abort "Migration failed." }
    } else {
        Write-Log "  run-migrations.ps1 not found -- skipping migrations." 'Yellow'
    }
} else {
    Write-Log "  No migrations directory in update package -- skipping." 'Gray'
}

# --- Step 7: Restart services -------------------------------------------------
Write-Log "--- Step 7: Restarting services ---" 'Cyan'
foreach ($svcName in @('ParqueRMBackend', 'ParqueRMFrontend')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Start-Service -Name $svcName -ErrorAction SilentlyContinue
        Write-Log "  Started $svcName" 'Green'
    }
}

# --- Step 8: Show URLs --------------------------------------------------------
Write-Log "--- Update complete ---" 'Green'
$showScript = Join-Path $InstallDir 'tools\installer-scripts\show-final-url.ps1'
if (Test-Path $showScript) {
    & $showScript -InstallDir $InstallDir
} else {
    Write-Log "Frontend : $($cfg.frontendUrl)" 'Cyan'
    Write-Log "Backend  : $($cfg.backendUrl)" 'Cyan'
}
Write-Log "Log file: $LogFile" 'Gray'
