#Requires -Version 5.1
<#
.SYNOPSIS
    Applies pending SQLite migrations to the ParqueRM database.

.DESCRIPTION
    Scans the migrations folder for .sql files in alphabetical order.
    Only runs files not yet recorded in schema_migrations.
    Stops on any error.
#>
param(
    [string]$MigrationsDir = '',
    [string]$SqlitePath    = '',
    [string]$DbPath        = 'C:\ParqueRM\data\parquerm.db',
    [string]$RuntimeDir    = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

if ([string]::IsNullOrWhiteSpace($RuntimeDir)) {
    $RuntimeDir = Join-Path (Split-Path (Split-Path $ScriptDir -Parent) -Parent) 'runtime'
}

if ([string]::IsNullOrWhiteSpace($MigrationsDir)) {
    $installed = 'C:\ParqueRM\app\database\migrations'
    $devPath = Join-Path $ScriptDir '..\..\db\migrations'
    if (Test-Path $installed) {
        $MigrationsDir = $installed
    } elseif (Test-Path $devPath) {
        $MigrationsDir = (Resolve-Path $devPath).Path
    } else {
        throw "Migrations directory not found. Pass -MigrationsDir explicitly."
    }
}

if (-not (Test-Path $MigrationsDir)) {
    throw "Migrations directory does not exist: $MigrationsDir"
}

function Find-Sqlite {
    if (-not [string]::IsNullOrWhiteSpace($SqlitePath) -and (Test-Path $SqlitePath)) {
        return $SqlitePath
    }

    $candidates = @(
        (Join-Path $RuntimeDir 'sqlite\sqlite3.exe'),
        (Join-Path $ScriptDir '..\..\runtime-cache\sqlite\sqlite3.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }

    $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return ''
}

$sqlite = Find-Sqlite
if ([string]::IsNullOrWhiteSpace($sqlite)) {
    throw "sqlite3.exe not found. Expected runtime\sqlite\sqlite3.exe."
}

$dbDir = Split-Path $DbPath -Parent
if (-not (Test-Path $dbDir)) { New-Item -ItemType Directory -Path $dbDir -Force | Out-Null }

Write-Host "Using sqlite3: $sqlite" -ForegroundColor Gray
Write-Host "Database: $DbPath" -ForegroundColor Gray

function Invoke-SqliteChecked {
    param(
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $sqlite @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        $details = @($output | ForEach-Object { $_.ToString() } | Where-Object { $_ })
        if ($details.Count -gt 0) {
            throw "$FailureMessage`n$($details -join [Environment]::NewLine)"
        }
        throw $FailureMessage
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function Invoke-SqliteQuery([string]$Sql) {
    return @(Invoke-SqliteChecked -Arguments @($DbPath, '-batch', '-noheader', $Sql) -FailureMessage 'SQLite query failed.')
}

function Invoke-SqliteFile([string]$FilePath) {
    $fileName = Split-Path $FilePath -Leaf
    Invoke-SqliteChecked -Arguments @($DbPath, '-batch', ".read $FilePath") -FailureMessage "Migration failed: $fileName." | Out-Null
}

Write-Host "Ensuring schema_migrations table exists..." -ForegroundColor Cyan
Invoke-SqliteQuery @"
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS schema_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    migration_name TEXT NOT NULL UNIQUE,
    checksum TEXT NULL,
    applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null

$applied = @{}
$rows = @(Invoke-SqliteQuery "SELECT migration_name FROM schema_migrations;")
foreach ($row in $rows) {
    $name = $row.Trim()
    if ($name) { $applied[$name] = $true }
}

$files = @(Get-ChildItem -Path $MigrationsDir -Filter '*.sql' -File -ErrorAction SilentlyContinue | Sort-Object Name)
if ($files.Count -eq 0) {
    Write-Host "No migration files found in $MigrationsDir" -ForegroundColor Yellow
    return
}

Write-Host "Found $($files.Count) migration file(s)." -ForegroundColor Gray

$appliedCount = 0
$skippedCount = 0

foreach ($file in $files) {
    $name = $file.Name

    if ($applied.ContainsKey($name)) {
        Write-Host "  [SKIP]    $name -- already applied" -ForegroundColor Gray
        $skippedCount++
        continue
    }

    Write-Host "  [RUNNING] $name ..." -ForegroundColor Yellow
    Invoke-SqliteFile $file.FullName

    $escapedName = $name.Replace("'", "''")
    Invoke-SqliteQuery "INSERT INTO schema_migrations (migration_name) VALUES ('$escapedName');" | Out-Null

    Write-Host "  [APPLIED] $name" -ForegroundColor Green
    $appliedCount++
}

Write-Host ""
Write-Host "Migrations complete: $appliedCount applied, $skippedCount skipped." -ForegroundColor Cyan
