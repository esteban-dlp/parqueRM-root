#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Initializes the local ParqueRM SQLite database.

.DESCRIPTION
    Creates/uses C:\ParqueRM\data\parquerm.db, runs the SQLite schema/seed
    scripts, prepares the initial admin user, applies pending migrations, and
    writes config\db-ready.json for service installation.
#>
param(
    [string]$InstallDir       = 'C:\ParqueRM',
    [string]$RuntimeCacheDir  = '',
    [string]$AdminPassword    = '',
    [string]$AdminPasswordEnv = '',
    [string]$InitScriptsDir   = '',
    [string]$MigrationsDir    = '',
    [string]$DbPath           = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DefaultAdminPassword = 'admin1'
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

if ([string]::IsNullOrWhiteSpace($RuntimeCacheDir)) {
    $RuntimeCacheDir = Join-Path $InstallDir 'runtime'
}
if ([string]::IsNullOrWhiteSpace($DbPath)) {
    $DbPath = Join-Path $InstallDir 'data\parquerm.db'
}
if ([string]::IsNullOrWhiteSpace($InitScriptsDir)) {
    $candidate = Join-Path $InstallDir 'app\database\init'
    if (Test-Path $candidate) {
        $InitScriptsDir = $candidate
    } else {
        $devPath = Join-Path $ScriptDir '..\..\db\init'
        $InitScriptsDir = if (Test-Path $devPath) { (Resolve-Path $devPath).Path } else { $candidate }
    }
}
if ([string]::IsNullOrWhiteSpace($MigrationsDir)) {
    $candidate = Join-Path $InstallDir 'app\database\migrations'
    if (Test-Path $candidate) {
        $MigrationsDir = $candidate
    } else {
        $devPath = Join-Path $ScriptDir '..\..\db\migrations'
        $MigrationsDir = if (Test-Path $devPath) { (Resolve-Path $devPath).Path } else { $candidate }
    }
}

$LogDir = Join-Path $InstallDir 'logs\db-init'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir "db-init-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ConfigDir = Join-Path $InstallDir 'config'
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
$DbReadyPath = Join-Path $ConfigDir 'db-ready.json'
Remove-Item -Path $DbReadyPath -Force -ErrorAction SilentlyContinue

function Write-Log([string]$Message, [string]$Color = 'White') {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line
}

function Resolve-AdminPassword {
    if (-not [string]::IsNullOrWhiteSpace($AdminPasswordEnv)) {
        $envValue = [Environment]::GetEnvironmentVariable($AdminPasswordEnv, 'Process')
        if ($null -ne $envValue) { return $envValue }

        Write-Log "ERROR: Admin password environment variable '$AdminPasswordEnv' was not available." 'Red'
        exit 1
    }

    if (-not [string]::IsNullOrEmpty($AdminPassword)) { return $AdminPassword }
    return $DefaultAdminPassword
}

function Get-BackendNodePath {
    $nodePath = Join-Path $RuntimeCacheDir 'node\node.exe'
    if (Test-Path $nodePath) { return $nodePath }

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd -and (Test-Path $nodeCmd.Source)) { return $nodeCmd.Source }

    return ''
}

function New-BcryptHash([string]$PlainTextPassword) {
    if ([string]::IsNullOrWhiteSpace($PlainTextPassword)) {
        Write-Log 'ERROR: Initial admin password is required.' 'Red'
        exit 1
    }

    $nodePath = Get-BackendNodePath
    if ([string]::IsNullOrWhiteSpace($nodePath)) {
        Write-Log 'ERROR: node.exe not found; cannot hash admin password.' 'Red'
        exit 1
    }

    $backendDir = Join-Path $InstallDir 'app\backend'
    $script = "const path=require('path'); const bcrypt=require(path.join(process.cwd(),'node_modules','bcrypt')); bcrypt.hash(process.env.PARQUERM_ADMIN_PASSWORD,12).then(h=>process.stdout.write(h)).catch(e=>{console.error(e && e.stack || e); process.exit(1);});"
    $oldPasswordEnv = $env:PARQUERM_ADMIN_PASSWORD
    $env:PARQUERM_ADMIN_PASSWORD = $PlainTextPassword
    try {
        Push-Location $backendDir
        try {
            $hash = & $nodePath -e $script
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($hash)) {
                Write-Log 'ERROR: Failed to hash admin password.' 'Red'
                exit 1
            }
            return ($hash | Select-Object -First 1).Trim()
        } finally {
            Pop-Location
        }
    } finally {
        $env:PARQUERM_ADMIN_PASSWORD = $oldPasswordEnv
    }
}

function Test-BcryptHash([string]$PlainTextPassword, [string]$Hash) {
    if ([string]::IsNullOrWhiteSpace($PlainTextPassword) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $false
    }

    $nodePath = Get-BackendNodePath
    if ([string]::IsNullOrWhiteSpace($nodePath)) {
        Write-Log 'ERROR: node.exe not found; cannot verify admin password.' 'Red'
        return $false
    }

    $backendDir = Join-Path $InstallDir 'app\backend'
    $script = "const path=require('path'); const bcrypt=require(path.join(process.cwd(),'node_modules','bcrypt')); bcrypt.compare(process.env.PARQUERM_ADMIN_PASSWORD,process.env.PARQUERM_ADMIN_HASH).then(ok=>process.stdout.write(ok?'true':'false')).catch(e=>{console.error(e && e.stack || e); process.exit(1);});"
    $oldPasswordEnv = $env:PARQUERM_ADMIN_PASSWORD
    $oldHashEnv = $env:PARQUERM_ADMIN_HASH
    $env:PARQUERM_ADMIN_PASSWORD = $PlainTextPassword
    $env:PARQUERM_ADMIN_HASH = $Hash
    try {
        Push-Location $backendDir
        try {
            $result = & $nodePath -e $script
            if ($LASTEXITCODE -ne 0) { return $false }
            return (($result | Select-Object -First 1).Trim() -eq 'true')
        } finally {
            Pop-Location
        }
    } finally {
        $env:PARQUERM_ADMIN_PASSWORD = $oldPasswordEnv
        $env:PARQUERM_ADMIN_HASH = $oldHashEnv
    }
}

function Get-SecretFingerprint([string]$Value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }

    $hex = (($hashBytes | ForEach-Object { $_.ToString('x2') }) -join '')
    return $hex.Substring(0, 12)
}

function Find-Sqlite {
    $candidates = @(
        (Join-Path $RuntimeCacheDir 'sqlite\sqlite3.exe'),
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
    Write-Log 'ERROR: sqlite3.exe not found. Expected runtime\sqlite\sqlite3.exe.' 'Red'
    exit 1
}

$DbDir = Split-Path $DbPath -Parent
if (-not (Test-Path $DbDir)) { New-Item -ItemType Directory -Path $DbDir -Force | Out-Null }

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

    if ($output) {
        $output | ForEach-Object { Add-Content -Path $LogFile -Value $_ }
    }
    if ($exitCode -ne 0) {
        Write-Log $FailureMessage 'Red'
        if ($output) {
            $output | Select-Object -Last 8 | ForEach-Object { Write-Log "  $_" 'Red' }
        }
        exit 1
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function Invoke-SqliteQuery([string]$Sql, [string]$FailureMessage = 'SQLite query failed.') {
    return @(Invoke-SqliteChecked -Arguments @($DbPath, '-batch', '-noheader', $Sql) -FailureMessage $FailureMessage)
}

function Invoke-SqliteFile([string]$FilePath) {
    $fileName = Split-Path $FilePath -Leaf
    $readArg = ".read '$($FilePath.Replace("'", "''"))'"
    Invoke-SqliteChecked -Arguments @($DbPath, '-batch', $readArg) -FailureMessage "SQL script failed: $fileName" | Out-Null
}

function Test-TableExists([string]$TableName) {
    $escaped = $TableName.Replace("'", "''")
    $rows = @(Invoke-SqliteQuery "SELECT name FROM sqlite_master WHERE type='table' AND name='$escaped' LIMIT 1;" 'Failed to inspect SQLite schema.')
    return (@($rows | Where-Object { $_.Trim() -eq $TableName }).Count -gt 0)
}

function Test-AdminUserExists {
    if (-not (Test-TableExists 'users')) { return $false }
    $rows = @(Invoke-SqliteQuery "SELECT 1 FROM users WHERE username='admin' LIMIT 1;" 'Failed to inspect existing admin user.')
    return (@($rows | Where-Object { $_.Trim() -eq '1' }).Count -gt 0)
}

function Get-AdminPasswordHash {
    $rows = @(Invoke-SqliteQuery "SELECT password_hash FROM users WHERE username='admin' LIMIT 1;" 'Failed to verify initial admin user password.')
    return @($rows | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1)
}

trap {
    try {
        Write-Log "UNHANDLED ERROR: $($_.Exception.Message)" 'Red'
        if ($_.ScriptStackTrace) { Write-Log "STACK: $($_.ScriptStackTrace)" 'Red' }
    } catch {
        Write-Host "UNHANDLED ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}

Write-Log '=== SQLite database initialization ===' 'Cyan'
Write-Log "Using sqlite3: $sqlite" 'Gray'
Write-Log "Database file: $DbPath" 'Gray'

$adminUserExistedBeforeInit = Test-AdminUserExists
$adminPasswordExplicitlyProvided = (
    -not [string]::IsNullOrWhiteSpace($AdminPasswordEnv) -or
    -not [string]::IsNullOrEmpty($AdminPassword)
)

Write-Log '=== Migration tracking table ===' 'Cyan'
$schemaMigrationScript = Join-Path $MigrationsDir '001_create_schema_migrations.sql'
if (Test-Path $schemaMigrationScript) {
    Invoke-SqliteFile $schemaMigrationScript
    Write-Log '  [OK] 001_create_schema_migrations.sql' 'Green'
} else {
    Invoke-SqliteQuery @"
CREATE TABLE IF NOT EXISTS schema_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    migration_name TEXT NOT NULL UNIQUE,
    checksum TEXT NULL,
    applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"@ 'Failed to ensure schema_migrations table.' | Out-Null
    Write-Log '  [OK] schema_migrations ensured inline' 'Green'
}

Write-Log '=== Init scripts ===' 'Cyan'
if (-not (Test-Path $InitScriptsDir)) {
    Write-Log "ERROR: Init scripts directory not found: $InitScriptsDir" 'Red'
    exit 1
}

$initFiles = @(Get-ChildItem $InitScriptsDir -Filter '*.sql' -File | Sort-Object Name)
foreach ($file in $initFiles) {
    Write-Log "  Running $($file.Name) ..." 'Yellow'
    Invoke-SqliteFile $file.FullName
    Write-Log "  [OK] $($file.Name)" 'Green'
}

Write-Log '=== Admin user password ===' 'Cyan'
if ($adminUserExistedBeforeInit -and -not $adminPasswordExplicitlyProvided) {
    Write-Log 'Admin user already existed before this install. Existing admin password was preserved.' 'Green'
} else {
    $resolvedAdminPassword = Resolve-AdminPassword
    Write-Log "Initial admin password ready for hashing (length: $($resolvedAdminPassword.Length), sha256-12: $(Get-SecretFingerprint $resolvedAdminPassword))." 'Gray'
    $adminPasswordHash = New-BcryptHash $resolvedAdminPassword
    $adminHashSql = $adminPasswordHash.Replace("'", "''")

    $setAdminPasswordSql = @"
PRAGMA foreign_keys = ON;
UPDATE roles
SET is_active = 1,
    deleted_at = NULL,
    updated_at = CURRENT_TIMESTAMP
WHERE name = 'Administrador';

INSERT OR IGNORE INTO users (
    role_id,
    username,
    password_hash,
    full_name,
    email,
    is_active,
    last_login_at,
    created_at,
    updated_at
)
SELECT
    (SELECT id FROM roles WHERE name = 'Administrador' ORDER BY id LIMIT 1),
    'admin',
    '$adminHashSql',
    'Administrador del Sistema',
    'admin@parquerm.local',
    1,
    NULL,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP;

UPDATE users
SET password_hash = '$adminHashSql',
    role_id = COALESCE((SELECT id FROM roles WHERE name = 'Administrador' ORDER BY id LIMIT 1), role_id),
    is_active = 1,
    deleted_at = NULL,
    updated_at = CURRENT_TIMESTAMP
WHERE username = 'admin';
"@

    Invoke-SqliteQuery $setAdminPasswordSql 'Failed to set initial admin user password.' | Out-Null
    $storedAdminHash = Get-AdminPasswordHash
    if (-not (Test-BcryptHash $resolvedAdminPassword $storedAdminHash)) {
        Write-Log 'ERROR: Initial admin user password was written, but bcrypt verification did not match.' 'Red'
        exit 1
    }
    Write-Log 'Initial admin user password ready and verified.' 'Green'
}

Write-Log '=== Migrations ===' 'Cyan'
$migrateScript = Join-Path $ScriptDir 'run-migrations.ps1'
if (Test-Path $migrateScript) {
    & $migrateScript -SqlitePath $sqlite -DbPath $DbPath -RuntimeDir $RuntimeCacheDir -MigrationsDir $MigrationsDir
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'Migration step failed.' 'Red'
        exit 1
    }
} else {
    Write-Log 'run-migrations.ps1 not found -- skipping.' 'Yellow'
}

Write-Log '=== Database initialization complete ===' 'Green'
Write-Log "Log file: $LogFile" 'Gray'

$dbReady = [ordered]@{
    type        = 'better-sqlite3'
    dbPath      = $DbPath
    completedAt = (Get-Date).ToString('s')
} | ConvertTo-Json -Depth 2
$dbReady | Out-File -FilePath $DbReadyPath -Encoding utf8 -NoNewline
Write-Log "DB readiness marker written: $DbReadyPath" 'Gray'
