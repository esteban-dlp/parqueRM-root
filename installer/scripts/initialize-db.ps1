#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs SQL Server Express (if needed) and initializes the ParqueRM database.

.DESCRIPTION
    1. Detects if SQL Server Express is already installed.
    2. If not, runs the offline installer from runtime-cache\sqlserver-express\.
    3. Creates the ParqueRM database if missing.
    4. Runs all db\init scripts (idempotent -- safe to re-run).
    5. Runs pending db\migrations.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM

.PARAMETER RuntimeCacheDir
    Path to runtime-cache. Default: auto-detected from script location.

.PARAMETER DbPassword
    SQL Server SA password. REQUIRED.

.PARAMETER DbName
    Database name. Default: ParqueRM

.PARAMETER SkipSqlServerInstall
    Skip SQL Server Express installation (use if already installed).

.PARAMETER InitScriptsDir
    Path to db\init scripts folder. Default: auto-detected.

.PARAMETER MigrationsDir
    Path to db\migrations folder. Default: auto-detected.
#>
param(
    [string]$InstallDir           = 'C:\ParqueRM',
    [string]$RuntimeCacheDir      = '',
    [Parameter(Mandatory)]
    [string]$DbPassword,
    [string]$DbName               = 'ParqueRM',
    [switch]$SkipSqlServerInstall,
    [string]$InitScriptsDir       = '',
    [string]$MigrationsDir        = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

if ([string]::IsNullOrWhiteSpace($RuntimeCacheDir)) {
    $RuntimeCacheDir = Join-Path $InstallDir 'runtime'
}
if ([string]::IsNullOrWhiteSpace($InitScriptsDir)) {
    # Installed path: C:\ParqueRM\app\database\init
    $candidate = Join-Path $InstallDir 'app\database\init'
    if (Test-Path $candidate) {
        $InitScriptsDir = $candidate
    } else {
        # Dev path: installer\scripts -> installer -> root -> db\init
        $devPath = Join-Path $ScriptDir '..\..\db\init'
        $InitScriptsDir = if (Test-Path $devPath) { $devPath } else { $candidate }
    }
}
if ([string]::IsNullOrWhiteSpace($MigrationsDir)) {
    $candidate = Join-Path $InstallDir 'app\database\migrations'
    if (Test-Path $candidate) {
        $MigrationsDir = $candidate
    } else {
        $devPath = Join-Path $ScriptDir '..\..\db\migrations'
        $MigrationsDir = if (Test-Path $devPath) { $devPath } else { $candidate }
    }
}

$LogDir = Join-Path $InstallDir 'logs\db-init'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir "db-init-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log([string]$msg, [string]$color = 'White') {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line
}

# --- Locate sqlcmd ------------------------------------------------------------
$sqlcmdCmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
$sqlcmd = if ($sqlcmdCmd) { $sqlcmdCmd.Source } else { $null }
if (-not $sqlcmd) {
    $candidates = @(
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe',
        (Join-Path $RuntimeCacheDir 'sqlcmd\sqlcmd.exe')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $sqlcmd = $c; break } }
}

# --- Step 1: SQL Server Express install ---------------------------------------
Write-Log "=== Step 1: SQL Server Express ===" 'Cyan'

$sqlServerInstalled = $false
$services = Get-Service -Name 'MSSQL*' -ErrorAction SilentlyContinue
if ($services | Where-Object { $_.DisplayName -like '*SQL Server*' -and $_.Name -notlike '*Agent*' -and $_.Name -notlike '*Browser*' }) {
    $sqlServerInstalled = $true
    Write-Log "SQL Server already installed." 'Green'
}

if (-not $sqlServerInstalled -and -not $SkipSqlServerInstall) {
    $sqlExpressCache = Join-Path $RuntimeCacheDir 'sqlserver-express'
    $sqlSetup = Get-ChildItem $sqlExpressCache -Filter 'SQLEXPR*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sqlSetup) {
        Write-Log "ERROR: SQL Server Express installer not found in: $sqlExpressCache" 'Red'
        Write-Log "Place SQLEXPR_x64_ENU.exe (or similar) in that folder." 'Yellow'
        exit 1
    }

    Write-Log "Installing SQL Server Express from $($sqlSetup.FullName) ..." 'Yellow'
    $sqlArgs = "/Q /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=`"$DbPassword`" /TCPENABLED=1 /IACCEPTSQLSERVERLICENSETERMS"
    $proc = Start-Process -FilePath $sqlSetup.FullName -ArgumentList $sqlArgs -Wait -PassThru
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        Write-Log "SQL Server installation failed (exit code $($proc.ExitCode))." 'Red'
        exit 1
    }
    Write-Log "SQL Server Express installed successfully." 'Green'
    if ($proc.ExitCode -eq 3010) {
        Write-Log "WARNING: Reboot required to complete SQL Server installation." 'Yellow'
    }
}

# --- Step 2: Ensure SQL Server service is running -----------------------------
Write-Log "=== Step 2: SQL Server service ===" 'Cyan'
$svc = Get-Service -Name 'MSSQLSERVER' -ErrorAction SilentlyContinue
if (-not $svc) { $svc = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue }
if (-not $svc) {
    Write-Log "ERROR: Could not find SQL Server service. Check installation." 'Red'
    exit 1
}
if ($svc.Status -ne 'Running') {
    Write-Log "Starting SQL Server service $($svc.Name)..." 'Yellow'
    Start-Service $svc.Name
    Start-Sleep -Seconds 5
}
Write-Log "SQL Server service is running." 'Green'

# --- Step 3: Ensure sqlcmd available -----------------------------------------
if (-not $sqlcmd) {
    Write-Log "ERROR: sqlcmd not found. Install SQL Server Command Line Tools." 'Red'
    exit 1
}
Write-Log "Using sqlcmd: $sqlcmd" 'Gray'

$sqlArgs = @('-S', 'localhost,1433', '-U', 'sa', '-P', $DbPassword)

# --- Step 4: Create database --------------------------------------------------
Write-Log "=== Step 3: Creating database '$DbName' ===" 'Cyan'
$createDb = "IF DB_ID('$DbName') IS NULL BEGIN CREATE DATABASE [$DbName]; END"
& $sqlcmd @sqlArgs '-Q' $createDb '-b'
if ($LASTEXITCODE -ne 0) { Write-Log "Failed to create database." 'Red'; exit 1 }
Write-Log "Database '$DbName' ready." 'Green'

# --- Step 5: Run init scripts -------------------------------------------------
Write-Log "=== Step 4: Init scripts ===" 'Cyan'
if (-not (Test-Path $InitScriptsDir)) {
    Write-Log "Init scripts directory not found: $InitScriptsDir" 'Yellow'
} else {
    $initFiles = Get-ChildItem $InitScriptsDir -Filter '*.sql' | Sort-Object Name |
        Where-Object { $_.Name -ne '01_create_database.sql' }  # DB already created above

    foreach ($f in $initFiles) {
        Write-Log "  Running $($f.Name) ..." 'Yellow'
        & $sqlcmd @sqlArgs '-d' $DbName '-i' $f.FullName '-b' | Tee-Object -Append -FilePath $LogFile
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Init script failed: $($f.Name)" 'Red'
            exit 1
        }
        Write-Log "  [OK] $($f.Name)" 'Green'
    }
}

# --- Step 6: Run migrations ---------------------------------------------------
Write-Log "=== Step 5: Migrations ===" 'Cyan'
$migrateScript = Join-Path $ScriptDir 'run-migrations.ps1'
if (Test-Path $migrateScript) {
    & $migrateScript -DbPassword $DbPassword -DbName $DbName -MigrationsDir $MigrationsDir
    if ($LASTEXITCODE -ne 0) { Write-Log "Migration step failed." 'Red'; exit 1 }
} else {
    Write-Log "run-migrations.ps1 not found -- skipping." 'Yellow'
}

Write-Log "=== Database initialization complete ===" 'Green'
Write-Log "Log file: $LogFile" 'Gray'
