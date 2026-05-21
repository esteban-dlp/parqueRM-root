#Requires -Version 5.1
<#
.SYNOPSIS
    Applies pending SQL migrations to the ParqueRM database.

.DESCRIPTION
    Scans the migrations folder for .sql files in alphabetical order.
    Only runs files not yet recorded in schema_migrations.
    Stops on any error -- does NOT silently skip failures.

.PARAMETER MigrationsDir
    Path to the folder containing migration .sql files.
    Default: relative to this script -- parqueRM-root\db\migrations

.PARAMETER SqlcmdPath
    Path to sqlcmd.exe. Default: searches PATH then runtime tools.

.PARAMETER DbHost
    SQL Server host. Default: 127.0.0.1

.PARAMETER DbPort
    SQL Server port. Default: 1433

.PARAMETER DbUser
    SQL Server login. Default: sa

.PARAMETER DbPassword
    SQL Server password. REQUIRED.

.PARAMETER DbName
    Database name. Default: ParqueRM
#>
param(
    [string]$MigrationsDir = '',
    [string]$SqlcmdPath    = '',
    [string]$DbHost        = '127.0.0.1',
    [int]$DbPort           = 1433,
    [string]$DbUser        = 'sa',
    [Parameter(Mandatory)]
    [string]$DbPassword,
    [string]$DbName        = 'ParqueRM'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Resolve paths ------------------------------------------------------------
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

if ([string]::IsNullOrWhiteSpace($MigrationsDir)) {
    # Try installed path first: C:\ParqueRM\app\database\migrations
    $installed = 'C:\ParqueRM\app\database\migrations'
    # Then dev path: installer/scripts/../../db/migrations
    $devPath = Join-Path $ScriptDir '..\..\db\migrations'
    if (Test-Path $installed) {
        $MigrationsDir = $installed
    } elseif (Test-Path $devPath) {
        $MigrationsDir = (Resolve-Path $devPath).Path
    } else {
        Write-Error "Migrations directory not found. Pass -MigrationsDir explicitly."
        exit 1
    }
}

if (-not (Test-Path $MigrationsDir)) {
    Write-Error "Migrations directory does not exist: $MigrationsDir"
    exit 1
}

# --- Locate sqlcmd ------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($SqlcmdPath)) {
    $sqlcmdCmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    if ($sqlcmdCmd) { $SqlcmdPath = $sqlcmdCmd.Source }
    if (-not $SqlcmdPath) {
        # Try common install paths
        $candidates = @(
            'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
            'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe',
            'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe'
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $SqlcmdPath = $c; break }
        }
    }
}

if (-not $SqlcmdPath -or -not (Test-Path $SqlcmdPath)) {
    Write-Error "sqlcmd.exe not found. Install SQL Server command-line tools or pass -SqlcmdPath."
    exit 1
}

Write-Host "Using sqlcmd: $SqlcmdPath" -ForegroundColor Gray

# --- Shared sqlcmd args -------------------------------------------------------
$sqlArgs = @('-S', "${DbHost},${DbPort}", '-U', $DbUser, '-P', $DbPassword, '-d', $DbName)

function Invoke-Sqlcmd-File([string]$file) {
    & $SqlcmdPath @sqlArgs '-i' $file '-b'
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Migration failed: $(Split-Path $file -Leaf). sqlcmd exit code: $LASTEXITCODE"
        exit 1
    }
}

function Invoke-Sqlcmd-Query([string]$query) {
    $result = & $SqlcmdPath @sqlArgs '-Q' $query '-h' '-1' '-W' 2>&1
    return $result
}

# --- Ensure schema_migrations exists -----------------------------------------
Write-Host "Ensuring schema_migrations table exists..." -ForegroundColor Cyan
$createTable = @"
IF OBJECT_ID('schema_migrations', 'U') IS NULL
BEGIN
    CREATE TABLE schema_migrations (
        id             INT IDENTITY(1,1) PRIMARY KEY,
        migration_name NVARCHAR(255) NOT NULL UNIQUE,
        checksum       NVARCHAR(128) NULL,
        applied_at     DATETIME2    NOT NULL DEFAULT SYSDATETIME()
    );
END
"@
& $SqlcmdPath @sqlArgs '-Q' $createTable '-b'
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to ensure schema_migrations table."
    exit 1
}

# --- Get applied migrations ---------------------------------------------------
$applied = @{}
$rows = Invoke-Sqlcmd-Query "SET NOCOUNT ON; SELECT migration_name FROM schema_migrations"
foreach ($row in $rows) {
    $name = ($row -replace '^\s+|\s+$', '')
    if ($name) { $applied[$name] = $true }
}

# --- Get migration files ------------------------------------------------------
$files = Get-ChildItem -Path $MigrationsDir -Filter '*.sql' | Sort-Object Name

if ($files.Count -eq 0) {
    Write-Host "No migration files found in $MigrationsDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($files.Count) migration file(s)." -ForegroundColor Gray

$applied_count = 0
$skipped_count = 0

foreach ($file in $files) {
    $name = $file.Name

    if ($applied.ContainsKey($name)) {
        Write-Host "  [SKIP]    $name -- already applied" -ForegroundColor Gray
        $skipped_count++
        continue
    }

    Write-Host "  [RUNNING] $name ..." -ForegroundColor Yellow
    Invoke-Sqlcmd-File $file.FullName

    # Record success
    $recordSql = "INSERT INTO schema_migrations (migration_name) VALUES ('$($name -replace "'","''")')"
    & $SqlcmdPath @sqlArgs '-Q' $recordSql '-b'
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Migration ran but could not record in schema_migrations: $name"
        exit 1
    }

    Write-Host "  [APPLIED] $name" -ForegroundColor Green
    $applied_count++
}

Write-Host ""
Write-Host "Migrations complete: $applied_count applied, $skipped_count skipped." -ForegroundColor Cyan
