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
    [string]$DbPassword           = '',
    [string]$AdminPassword        = '',
    [string]$DbName               = 'ParqueRM',
    [string]$SkipSqlServerInstall = 'false',
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
$ConfigDir = Join-Path $InstallDir 'config'
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
$DbReadyPath = Join-Path $ConfigDir 'db-ready.json'
Remove-Item -Path $DbReadyPath -Force -ErrorAction SilentlyContinue

$skipSqlInstallFlag = $false
if ($SkipSqlServerInstall -match '^(1|true|yes)$') { $skipSqlInstallFlag = $true }

function Read-DotEnvValue([string]$Path, [string]$Key) {
    if (-not (Test-Path $Path)) { return '' }
    $line = Get-Content $Path | Where-Object { $_ -match "^$([regex]::Escape($Key))=" } | Select-Object -First 1
    if (-not $line) { return '' }
    $value = ($line -split '=', 2)[1]
    if ($value.Length -ge 2) {
        $first = $value.Substring(0, 1)
        $last = $value.Substring($value.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    return $value
}

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    $envPath = Join-Path $InstallDir 'app\backend\.env'
    $DbPassword = Read-DotEnvValue $envPath 'DB_PASSWORD'
}

function New-BcryptHash([string]$PlainTextPassword) {
    $defaultAdminHash = '$2b$12$.JFcotaaZqS6E/XbFow1Xuq0CdQVbEYRItqhm/FDI6cNVuTdmuX3e'
    if ([string]::IsNullOrWhiteSpace($PlainTextPassword)) { return $defaultAdminHash }

    $nodePath = Join-Path $RuntimeCacheDir 'node\node.exe'
    if (-not (Test-Path $nodePath)) {
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCmd) { $nodePath = $nodeCmd.Source }
    }
    if (-not (Test-Path $nodePath)) {
        Write-Log "ERROR: node.exe not found; cannot hash admin password." 'Red'
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
                Write-Log "ERROR: Failed to hash admin password." 'Red'
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

function Write-Log([string]$msg, [string]$color = 'White') {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line
}

function ConvertTo-SqlLiteral([string]$Value) {
    return "N'$($Value.Replace("'", "''"))'"
}

function Get-SqlEngineServices {
    @(Get-Service -Name 'MSSQL*' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*'
        } |
        Sort-Object @{ Expression = { if ($_.Name -eq 'MSSQLSERVER') { 0 } else { 1 } } }, Name)
}

function Get-SqlInstanceName([string]$ServiceName) {
    if ($ServiceName -eq 'MSSQLSERVER') { return 'MSSQLSERVER' }
    if ($ServiceName -like 'MSSQL$*') { return $ServiceName.Substring(6) }
    return ''
}

function Get-SqlInstanceRegistryId([string]$InstanceName) {
    $instanceNamesPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
    if (-not (Test-Path $instanceNamesPath)) { return '' }
    try {
        $props = Get-ItemProperty -Path $instanceNamesPath -ErrorAction Stop
        return [string]$props.$InstanceName
    } catch {
        return ''
    }
}

function Enable-SqlTcpPort1433([string]$ServiceName) {
    $instanceName = Get-SqlInstanceName $ServiceName
    $instanceId = Get-SqlInstanceRegistryId $instanceName
    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        Write-Log "WARNING: Could not find SQL registry instance id for '$instanceName'. TCP port configuration skipped." 'Yellow'
        return $false
    }

    $tcpRoot = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp"
    $ipAll = Join-Path $tcpRoot 'IPAll'
    if (-not (Test-Path $ipAll)) {
        Write-Log "WARNING: SQL TCP registry path not found: $ipAll" 'Yellow'
        return $false
    }

    Write-Log "Configuring SQL Server TCP/IP on 127.0.0.1:1433 for instance '$instanceName'..." 'Yellow'
    Set-ItemProperty -Path $tcpRoot -Name Enabled -Value 1 -ErrorAction SilentlyContinue
    Get-ChildItem -Path $tcpRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -like 'IP*' -and $_.PSChildName -ne 'IPAll' } |
        ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name Enabled -Value 1 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name Active -Value 1 -ErrorAction SilentlyContinue
        }
    Set-ItemProperty -Path $ipAll -Name TcpDynamicPorts -Value '' -ErrorAction Stop
    Set-ItemProperty -Path $ipAll -Name TcpPort -Value '1433' -ErrorAction Stop
    return $true
}

function Restart-SqlServiceAndWait([string]$ServiceName) {
    Write-Log "Restarting SQL Server service $ServiceName..." 'Yellow'
    Restart-Service -Name $ServiceName -Force -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds(90)
    do {
        $svcNow = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($svcNow.Status -eq 'Running') {
            Start-Sleep -Seconds 3
            Write-Log "SQL Server service $ServiceName is running." 'Green'
            return
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    Write-Log "ERROR: SQL Server service $ServiceName did not return to Running state." 'Red'
    exit 1
}

function Test-LocalSqlTcp {
    try {
        return (Test-NetConnection -ComputerName '127.0.0.1' -Port 1433 -InformationLevel Quiet -WarningAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Invoke-SqlcmdChecked {
    param(
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    $output = & $sqlcmd @Arguments 2>&1
    $exitCode = $LASTEXITCODE
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
    return $output
}

function Test-SaLogin([string[]]$Arguments) {
    $output = & $sqlcmd @Arguments '-Q' 'SELECT 1' '-b' 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and $output) {
        $output | ForEach-Object { Add-Content -Path $LogFile -Value $_ }
    }
    return ($exitCode -eq 0)
}

function Repair-SaLoginWithWindowsAuth([string]$Password) {
    $passwordLiteral = ConvertTo-SqlLiteral $Password
    $instanceId = Get-SqlInstanceRegistryId $sqlInstanceName
    if (-not [string]::IsNullOrWhiteSpace($instanceId)) {
        $loginModePath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer"
        if (Test-Path $loginModePath) {
            Set-ItemProperty -Path $loginModePath -Name LoginMode -Value 2 -ErrorAction SilentlyContinue
        }
    }
    $repairSql = @"
ALTER LOGIN [sa] ENABLE;
ALTER LOGIN [sa] WITH PASSWORD=$passwordLiteral UNLOCK;
"@

    Write-Log "Attempting to enable/update SQL 'sa' login using Windows authentication..." 'Yellow'
    $output = & $sqlcmd '-S' '127.0.0.1,1433' '-E' '-Q' $repairSql '-b' 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Add-Content -Path $LogFile -Value $_ }
    }
    if ($exitCode -ne 0) {
        Write-Log "ERROR: Could not login with 'sa', and Windows authentication could not repair it." 'Red'
        Write-Log "       If SQL Server was already installed, enter the current SQL 'sa' password or reset it manually." 'Yellow'
        if ($output) {
            $output | Select-Object -Last 8 | ForEach-Object { Write-Log "  $_" 'Red' }
        }
        exit 1
    }
    return $true
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
$engineServices = Get-SqlEngineServices
if ($engineServices.Count -gt 0) {
    $sqlServerInstalled = $true
    Write-Log "SQL Server already installed: $($engineServices.Name -join ', ')" 'Green'
}

if (-not $sqlServerInstalled -and -not $skipSqlInstallFlag) {
    if ([string]::IsNullOrWhiteSpace($DbPassword)) {
        Write-Log "ERROR: DbPassword is required to install SQL Server." 'Red'
        exit 1
    }

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
$engineServices = Get-SqlEngineServices
$svc = $engineServices | Select-Object -First 1
if (-not $svc) {
    Write-Log "ERROR: Could not find SQL Server service. Check installation." 'Red'
    exit 1
}
$sqlServiceName = $svc.Name
$sqlInstanceName = Get-SqlInstanceName $sqlServiceName
Write-Log "Using SQL Server service: $sqlServiceName (instance: $sqlInstanceName)" 'Gray'
if ($svc.Status -ne 'Running') {
    Write-Log "Starting SQL Server service $sqlServiceName..." 'Yellow'
    Start-Service $sqlServiceName
    Start-Sleep -Seconds 5
}
Write-Log "SQL Server service is running." 'Green'

# --- Step 3: Ensure sqlcmd available -----------------------------------------
if (-not $sqlcmd) {
    Write-Log "ERROR: sqlcmd not found. Install SQL Server Command Line Tools." 'Red'
    exit 1
}
Write-Log "Using sqlcmd: $sqlcmd" 'Gray'

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    Write-Log "ERROR: DbPassword is required to initialize database '$DbName'." 'Red'
    exit 1
}

if (Enable-SqlTcpPort1433 $sqlServiceName) {
    Restart-SqlServiceAndWait $sqlServiceName
}

if (-not (Test-LocalSqlTcp)) {
    Write-Log "ERROR: SQL Server is not listening on 127.0.0.1:1433." 'Red'
    Write-Log "       Check SQL Server TCP/IP configuration and make sure no other process is using port 1433." 'Yellow'
    exit 1
}
Write-Log "SQL Server is listening on 127.0.0.1:1433." 'Green'

$sqlArgs = @('-S', '127.0.0.1,1433', '-U', 'sa', '-P', $DbPassword)
if (-not (Test-SaLogin $sqlArgs)) {
    Repair-SaLoginWithWindowsAuth $DbPassword | Out-Null
    Restart-SqlServiceAndWait $sqlServiceName
    if (-not (Test-SaLogin $sqlArgs)) {
        Write-Log "ERROR: SQL 'sa' login still failed after repair attempt." 'Red'
        exit 1
    }
}
Write-Log "SQL 'sa' login verified." 'Green'

$AdminPasswordHash = New-BcryptHash $AdminPassword

# --- Step 4: Create database --------------------------------------------------
Write-Log "=== Step 3: Creating database '$DbName' ===" 'Cyan'
$createDb = "IF DB_ID('$DbName') IS NULL BEGIN CREATE DATABASE [$DbName]; END"
Invoke-SqlcmdChecked -Arguments ($sqlArgs + @('-Q', $createDb, '-b')) -FailureMessage "Failed to create database '$DbName'." | Out-Null
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
        Invoke-SqlcmdChecked -Arguments ($sqlArgs + @('-d', $DbName, '-i', $f.FullName, '-b')) -FailureMessage "Init script failed: $($f.Name)" | Out-Null
        Write-Log "  [OK] $($f.Name)" 'Green'
    }
}

# --- Step 5b: Set installer-provided admin password ---------------------------
Write-Log "=== Step 4b: Admin user password ===" 'Cyan'
$adminHashSql = $AdminPasswordHash.Replace("'", "''")
$setAdminPasswordSql = @"
UPDATE dbo.users
SET password_hash = N'$adminHashSql',
    is_active = 1,
    updated_at = SYSDATETIME()
WHERE username = N'admin';

IF @@ROWCOUNT = 0
BEGIN
    DECLARE @adminRoleId INT = (SELECT TOP 1 id FROM dbo.roles WHERE name = N'Administrador' ORDER BY id);
    INSERT INTO dbo.users
    (
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
    VALUES
    (
        @adminRoleId,
        N'admin',
        N'$adminHashSql',
        N'Administrador del Sistema',
        N'admin@parquerm.local',
        1,
        NULL,
        SYSDATETIME(),
        SYSDATETIME()
    );
END
"@

Invoke-SqlcmdChecked -Arguments ($sqlArgs + @('-d', $DbName, '-Q', $setAdminPasswordSql, '-b')) -FailureMessage 'Failed to set admin user password.' | Out-Null
Write-Log "Admin user password ready." 'Green'

# --- Step 6: Run migrations ---------------------------------------------------
Write-Log "=== Step 5: Migrations ===" 'Cyan'
$migrateScript = Join-Path $ScriptDir 'run-migrations.ps1'
if (Test-Path $migrateScript) {
    & $migrateScript -SqlcmdPath $sqlcmd -DbHost '127.0.0.1' -DbPassword $DbPassword -DbName $DbName -MigrationsDir $MigrationsDir
    if ($LASTEXITCODE -ne 0) { Write-Log "Migration step failed." 'Red'; exit 1 }
} else {
    Write-Log "run-migrations.ps1 not found -- skipping." 'Yellow'
}

Write-Log "=== Database initialization complete ===" 'Green'
Write-Log "Log file: $LogFile" 'Gray'

$dbReady = [ordered]@{
    database    = $DbName
    server      = '127.0.0.1,1433'
    service     = $sqlServiceName
    instance    = $sqlInstanceName
    completedAt = (Get-Date).ToString('s')
} | ConvertTo-Json -Depth 2
$dbReady | Out-File -FilePath $DbReadyPath -Encoding utf8 -NoNewline
Write-Log "DB readiness marker written: $DbReadyPath" 'Gray'
