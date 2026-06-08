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
    [string]$AdminPasswordEnv     = '',
    [string]$DbName               = 'ParqueRM',
    [string]$SkipSqlServerInstall = 'false',
    [string]$InitScriptsDir       = '',
    [string]$MigrationsDir        = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExitCodeSqlPasswordRetry = 11
$ExitCodeSqlRebootRequired = 12
$DefaultAdminPassword = 'admin1'

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
    if ([string]::IsNullOrWhiteSpace($PlainTextPassword)) {
        Write-Log "ERROR: Initial admin password is required." 'Red'
        exit 1
    }

    $nodePath = Get-BackendNodePath
    if ([string]::IsNullOrWhiteSpace($nodePath)) {
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

function Test-BcryptHash([string]$PlainTextPassword, [string]$Hash) {
    if ([string]::IsNullOrWhiteSpace($PlainTextPassword) -or [string]::IsNullOrWhiteSpace($Hash)) {
        return $false
    }

    $nodePath = Get-BackendNodePath
    if ([string]::IsNullOrWhiteSpace($nodePath)) {
        Write-Log "ERROR: node.exe not found; cannot verify admin password." 'Red'
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

function Get-BackendNodePath {
    $nodePath = Join-Path $RuntimeCacheDir 'node\node.exe'
    if (Test-Path $nodePath) { return $nodePath }

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd -and (Test-Path $nodeCmd.Source)) { return $nodeCmd.Source }

    return ''
}

function Write-Log([string]$msg, [string]$color = 'White') {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line
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

function Resolve-AdminPassword {
    if (-not [string]::IsNullOrWhiteSpace($AdminPasswordEnv)) {
        $envValue = [Environment]::GetEnvironmentVariable($AdminPasswordEnv, 'Process')
        if ($null -ne $envValue) {
            return $envValue
        }

        Write-Log "ERROR: Admin password environment variable '$AdminPasswordEnv' was not available to initialize-db.ps1." 'Red'
        exit 1
    }

    if (-not [string]::IsNullOrEmpty($AdminPassword)) {
        return $AdminPassword
    }

    return $DefaultAdminPassword
}

function ConvertTo-SqlLiteral([string]$Value) {
    return "N'$($Value.Replace("'", "''"))'"
}

function Invoke-NativeCommandCapture([scriptblock]$Command) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Command 2>&1
        $exitCode = $LASTEXITCODE
        return [PSCustomObject]@{
            Output   = @($output)
            ExitCode = $exitCode
        }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function ConvertTo-WindowsCommandLineArgument([string]$Value) {
    if ($null -eq $Value) { return '""' }

    $needsQuotes = ($Value.Length -eq 0 -or $Value -match '[\s"]')
    if (-not $needsQuotes) { return $Value }

    $result = '"'
    $backslashes = 0
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') {
            $backslashes++
            continue
        }

        if ($ch -eq '"') {
            $result += ('\' * (($backslashes * 2) + 1))
            $result += '"'
            $backslashes = 0
            continue
        }

        if ($backslashes -gt 0) {
            $result += ('\' * $backslashes)
            $backslashes = 0
        }
        $result += $ch
    }

    if ($backslashes -gt 0) {
        $result += ('\' * ($backslashes * 2))
    }
    $result += '"'
    return $result
}

function Join-WindowsCommandLine([string[]]$Arguments) {
    return (($Arguments | ForEach-Object { ConvertTo-WindowsCommandLineArgument $_ }) -join ' ')
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

function Get-SystemDriveRoot {
    $drive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($drive)) { $drive = 'C:' }
    return $drive.TrimEnd('\') + '\'
}

function Invoke-FsutilSectorInfo([string]$VolumeRoot) {
    try {
        $output = & fsutil fsinfo sectorinfo $VolumeRoot 2>&1
        return @(Format-CommandOutput $output)
    } catch {
        return @("fsutil failed: $($_.Exception.Message)")
    }
}

function Get-MaxPhysicalSectorBytes([string[]]$SectorInfoLines) {
    $values = @()
    foreach ($line in $SectorInfoLines) {
        if ($line -match '(?i)(physical|fisic|f.sic|atomic|performance|rendimiento).*?:\s*(\d+)') {
            $values += [int]$matches[2]
        }
    }

    if ($values.Count -eq 0) { return 0 }
    return ($values | Measure-Object -Maximum).Maximum
}

function Test-SqlSectorCompatibilityRegistryFixApplied {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device'
    if (-not (Test-Path $path)) { return $false }

    try {
        $props = Get-ItemProperty -Path $path -Name 'ForcedPhysicalSectorSizeInBytes' -ErrorAction Stop
        $value = @($props.ForcedPhysicalSectorSizeInBytes)
        return ($value -contains '* 4095')
    } catch {
        return $false
    }
}

function Enable-SqlSectorCompatibilityIfNeeded {
    $volume = Get-SystemDriveRoot
    Write-Log "Checking disk sector compatibility for SQL Server on $volume ..." 'Cyan'
    $sectorInfo = @(Invoke-FsutilSectorInfo $volume)
    if ($sectorInfo.Count -gt 0) {
        $sectorInfo | ForEach-Object { Add-Content -Path $LogFile -Value "  $_" }
    }

    $maxSectorBytes = Get-MaxPhysicalSectorBytes $sectorInfo
    if ($maxSectorBytes -le 0) {
        Write-Log "Could not parse physical sector size from fsutil output. Continuing without registry change." 'Yellow'
        return
    }

    Write-Log "Detected max physical sector size: $maxSectorBytes bytes." 'Gray'
    if ($maxSectorBytes -le 4096) {
        Write-Log "Disk sector size is compatible with SQL Server." 'Green'
        return
    }

    if (Test-SqlSectorCompatibilityRegistryFixApplied) {
        Write-Log "SQL Server NVMe sector compatibility registry fix is already present." 'Green'
        return
    }

    Write-Log "Detected physical sector size greater than 4096 bytes. Applying SQL Server NVMe compatibility registry fix..." 'Yellow'
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device'
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty `
        -Path $regPath `
        -Name 'ForcedPhysicalSectorSizeInBytes' `
        -PropertyType MultiString `
        -Force `
        -Value '* 4095' |
        Out-Null

    Write-Log "SQL Server NVMe sector compatibility registry fix applied." 'Green'
    Write-Log "Windows must be restarted before SQL Server can be installed or started reliably." 'Yellow'
    exit $ExitCodeSqlRebootRequired
}

function Write-RecentSqlErrorLogTail {
    $logRoots = @(
        'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Log',
        'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Log',
        'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Log'
    )

    foreach ($root in $logRoots) {
        if (-not (Test-Path $root)) { continue }
        $files = @(Get-ChildItem -Path $root -Filter 'ERRORLOG*' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 2)
        foreach ($file in $files) {
            Write-Log "SQL Server ERRORLOG tail: $($file.FullName)" 'Gray'
            Get-Content -Path $file.FullName -Tail 80 -ErrorAction SilentlyContinue |
                ForEach-Object { Add-Content -Path $LogFile -Value "  $_" }
        }
        return
    }
}

function Find-SqlServerUpdatePackage {
    $updatesDir = Join-Path $RuntimeCacheDir 'sqlserver-express\updates'
    if (-not (Test-Path $updatesDir)) { return $null }

    return Get-ChildItem -Path $updatesDir -Filter '*.exe' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)(SQLServer.*KB|KB\d+|CU)' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Invoke-SqlServerUpdateIfAvailable {
    $updatePackage = Find-SqlServerUpdatePackage
    if (-not $updatePackage) {
        Write-Log "No SQL Server cumulative update package found in runtime\sqlserver-express\updates." 'Gray'
        return
    }

    Write-Log "Applying SQL Server update package: $($updatePackage.FullName)" 'Yellow'
    $patchArgs = Join-WindowsCommandLine @(
        '/quiet',
        '/IAcceptSQLServerLicenseTerms',
        '/Action=Patch',
        '/AllInstances'
    )
    $proc = Start-Process -FilePath $updatePackage.FullName -ArgumentList $patchArgs -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-Log "SQL Server update package completed successfully." 'Green'
        return
    }
    if ($proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641) {
        Write-Log "SQL Server update package completed and requires Windows restart (exit code $($proc.ExitCode))." 'Yellow'
        exit $ExitCodeSqlRebootRequired
    }

    Write-Log "ERROR: SQL Server update package failed (exit code $($proc.ExitCode))." 'Red'
    Write-RecentSqlErrorLogTail
    exit 1
}

function Start-SqlServiceAndWait([string]$ServiceName) {
    Write-Log "Starting SQL Server service $ServiceName..." 'Yellow'
    try {
        Start-Service $ServiceName -ErrorAction Stop
    } catch {
        Write-Log "ERROR: Could not start SQL Server service ${ServiceName}: $($_.Exception.Message)" 'Red'
        Write-Log "       If this is a new NVMe/modern disk machine, check diagnostics for fsutil sector info and SQL ERRORLOG." 'Yellow'
        Write-RecentSqlErrorLogTail
        exit 1
    }

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

    Write-Log "ERROR: SQL Server service $ServiceName did not reach Running state." 'Red'
    Write-RecentSqlErrorLogTail
    exit 1
}

function Invoke-SqlcmdChecked {
    param(
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    $result = Invoke-NativeCommandCapture { & $sqlcmd @Arguments }
    $output = $result.Output
    $exitCode = $result.ExitCode
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

function Format-CommandOutput([object[]]$Output) {
    return @($Output | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-SqlcmdUnsupportedOption([object[]]$Output, [string]$OptionName) {
    $text = (@(Format-CommandOutput $Output) -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }

    $escapedOption = [regex]::Escape($OptionName)
    $optionFirstPattern = "(?i)(^|\s|:)[`"'\-]?$escapedOption[`"']?\s*:\s*unknown\s+(option|flag)"
    $unknownFirstPattern = "(?i)unknown\s+(option|flag|shorthand\s+flag).*?[`"'\-]?$escapedOption\b"
    return (($text -match $optionFirstPattern) -or ($text -match $unknownFirstPattern))
}

function Write-SqlcmdOutputToLog([object[]]$Output) {
    $lines = @(Format-CommandOutput $Output)
    if ($lines.Count -gt 0) {
        $lines | ForEach-Object { Add-Content -Path $LogFile -Value $_ }
    }
}

function Invoke-SqlcmdFileChecked {
    param(
        [string[]]$Arguments,
        [string]$FilePath,
        [string]$FailureMessage
    )

    $argsWithUtf8 = @($Arguments + @('-f', '65001', '-i', $FilePath, '-b'))
    $result = Invoke-NativeCommandCapture { & $sqlcmd @argsWithUtf8 }
    if ($result.ExitCode -ne 0 -and (Test-SqlcmdUnsupportedOption $result.Output 'f')) {
        Write-SqlcmdOutputToLog $result.Output
        Write-Log "sqlcmd does not support -f 65001; retrying $(Split-Path $FilePath -Leaf) without the UTF-8 flag." 'Yellow'
        $argsDefaultEncoding = @($Arguments + @('-i', $FilePath, '-b'))
        $result = Invoke-NativeCommandCapture { & $sqlcmd @argsDefaultEncoding }
    }

    Write-SqlcmdOutputToLog $result.Output
    if ($result.ExitCode -ne 0) {
        Write-Log $FailureMessage 'Red'
        $details = @(Format-CommandOutput $result.Output)
        if ($details.Count -gt 0) {
            $details | Select-Object -Last 8 | ForEach-Object { Write-Log "  $_" 'Red' }
        }
        exit 1
    }
}

function Test-AdminUserExists {
    $checkSql = @"
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.users', N'U') IS NULL
    SELECT 0;
ELSE
    EXEC sp_executesql N'IF EXISTS (SELECT 1 FROM dbo.users WHERE username = N''admin'') SELECT 1; ELSE SELECT 0;';
"@

    $rows = Invoke-SqlcmdChecked `
        -Arguments ($sqlArgs + @('-d', $DbName, '-Q', $checkSql, '-h', '-1', '-W', '-b')) `
        -FailureMessage 'Failed to inspect existing admin user.'

    $value = @($rows | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ } | Select-Object -First 1)
    return ($value -eq '1')
}

function Test-SaLogin([string[]]$Arguments) {
    $result = Invoke-NativeCommandCapture { & $sqlcmd @Arguments '-Q' 'SELECT 1' '-b' }
    $output = $result.Output
    $exitCode = $result.ExitCode
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
    $result = Invoke-NativeCommandCapture { & $sqlcmd '-S' '127.0.0.1,1433' '-E' '-Q' $repairSql '-b' }
    $output = $result.Output
    $exitCode = $result.ExitCode
    if ($output) {
        $output | ForEach-Object { Add-Content -Path $LogFile -Value $_ }
    }
    if ($exitCode -ne 0) {
        Write-Log "ERROR: Could not login with 'sa', and Windows authentication could not repair it." 'Red'
        Write-Log "       If SQL Server was already installed, enter the current SQL 'sa' password or reset it manually." 'Yellow'
        if ($output) {
            $output | Select-Object -Last 8 | ForEach-Object { Write-Log "  $_" 'Red' }
        }
        exit $ExitCodeSqlPasswordRetry
    }
    return $true
}

trap {
    try {
        Write-Log "UNHANDLED ERROR: $($_.Exception.Message)" 'Red'
        if ($_.ScriptStackTrace) {
            Write-Log "STACK: $($_.ScriptStackTrace)" 'Red'
        }
    } catch {
        Write-Host "UNHANDLED ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
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

# --- Preflight: SQL Server disk sector compatibility --------------------------
Write-Log "=== Preflight: SQL Server disk sector compatibility ===" 'Cyan'
Enable-SqlSectorCompatibilityIfNeeded

# --- Step 1: SQL Server Express install ---------------------------------------
Write-Log "=== Step 1: SQL Server Express ===" 'Cyan'

$sqlServerInstalled = $false
$engineServices = @(Get-SqlEngineServices)
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
    $updatesDir = Join-Path $sqlExpressCache 'updates'
    $sqlSetupArgs = @(
        '/Q',
        '/ACTION=Install',
        '/FEATURES=SQLEngine',
        '/INSTANCENAME=MSSQLSERVER',
        '/SECURITYMODE=SQL',
        "/SAPWD=$DbPassword",
        '/TCPENABLED=1',
        '/IACCEPTSQLSERVERLICENSETERMS'
    )
    if (Test-Path $updatesDir) {
        $updatePackages = @(Get-ChildItem -Path $updatesDir -Filter '*.exe' -File -ErrorAction SilentlyContinue)
        if ($updatePackages.Count -gt 0) {
            Write-Log "SQL Server setup will use update source: $updatesDir" 'Gray'
            $sqlSetupArgs += '/UPDATEENABLED=True'
            $sqlSetupArgs += "/UPDATESOURCE=$updatesDir"
        }
    }
    $sqlArgs = Join-WindowsCommandLine $sqlSetupArgs
    $proc = Start-Process -FilePath $sqlSetup.FullName -ArgumentList $sqlArgs -Wait -PassThru
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        Write-Log "SQL Server installation failed (exit code $($proc.ExitCode))." 'Red'
        Write-Log "This can happen when SQL Server rejects the provided 'sa' password. The installer should ask for a different SQL password and retry." 'Yellow'
        Write-RecentSqlErrorLogTail
        exit $ExitCodeSqlPasswordRetry
    }
    Write-Log "SQL Server Express installed successfully." 'Green'
    if ($proc.ExitCode -eq 3010) {
        Write-Log "SQL Server installation requires Windows restart." 'Yellow'
        exit $ExitCodeSqlRebootRequired
    }
}

$engineServices = @(Get-SqlEngineServices)
if ($engineServices.Count -gt 0) {
    Invoke-SqlServerUpdateIfAvailable
}

# --- Step 2: Ensure SQL Server service is running -----------------------------
Write-Log "=== Step 2: SQL Server service ===" 'Cyan'
$engineServices = @(Get-SqlEngineServices)
$svc = $engineServices | Select-Object -First 1
if (-not $svc) {
    Write-Log "ERROR: Could not find SQL Server service. Check installation." 'Red'
    exit 1
}
$sqlServiceName = $svc.Name
$sqlInstanceName = Get-SqlInstanceName $sqlServiceName
Write-Log "Using SQL Server service: $sqlServiceName (instance: $sqlInstanceName)" 'Gray'
if ($svc.Status -ne 'Running') {
    Start-SqlServiceAndWait $sqlServiceName
} else {
    Write-Log "SQL Server service is running." 'Green'
}

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
        exit $ExitCodeSqlPasswordRetry
    }
}
Write-Log "SQL 'sa' login verified." 'Green'

# --- Step 4: Create database --------------------------------------------------
Write-Log "=== Step 3: Creating database '$DbName' ===" 'Cyan'
$createDb = "IF DB_ID('$DbName') IS NULL BEGIN CREATE DATABASE [$DbName]; END"
Invoke-SqlcmdChecked -Arguments ($sqlArgs + @('-Q', $createDb, '-b')) -FailureMessage "Failed to create database '$DbName'." | Out-Null
Write-Log "Database '$DbName' ready." 'Green'

$adminUserExistedBeforeInit = Test-AdminUserExists
$adminPasswordExplicitlyProvided = (
    -not [string]::IsNullOrWhiteSpace($AdminPasswordEnv) -or
    -not [string]::IsNullOrEmpty($AdminPassword)
)
if ($adminUserExistedBeforeInit) {
    if ($adminPasswordExplicitlyProvided) {
        Write-Log "Existing admin user found before init scripts. Its password will be reset to the installer-provided value." 'Gray'
    } else {
        Write-Log "Existing admin user found before init scripts. Its password will be preserved." 'Gray'
    }
} else {
    Write-Log "No existing admin user found before init scripts. Initial admin password will be '$DefaultAdminPassword'." 'Gray'
}

# --- Step 5: Run init scripts -------------------------------------------------
Write-Log "=== Step 4: Init scripts ===" 'Cyan'
if (-not (Test-Path $InitScriptsDir)) {
    Write-Log "Init scripts directory not found: $InitScriptsDir" 'Yellow'
} else {
    $initFiles = Get-ChildItem $InitScriptsDir -Filter '*.sql' | Sort-Object Name |
        Where-Object { $_.Name -ne '01_create_database.sql' }  # DB already created above

    foreach ($f in $initFiles) {
        Write-Log "  Running $($f.Name) ..." 'Yellow'
        Invoke-SqlcmdFileChecked -Arguments ($sqlArgs + @('-d', $DbName)) -FilePath $f.FullName -FailureMessage "Init script failed: $($f.Name)"
        Write-Log "  [OK] $($f.Name)" 'Green'
    }
}

# --- Step 5b: Prepare initial admin password ----------------------------------
Write-Log "=== Step 4b: Admin user password ===" 'Cyan'
if ($adminUserExistedBeforeInit -and -not $adminPasswordExplicitlyProvided) {
    Write-Log "Admin user already existed before this install. Existing admin password was preserved." 'Green'
} else {
    $AdminPassword = Resolve-AdminPassword
    if ([string]::IsNullOrWhiteSpace($AdminPassword)) {
        Write-Log "ERROR: Initial admin password is required." 'Red'
        exit 1
    }
    Write-Log "Initial admin password ready for hashing (length: $($AdminPassword.Length), sha256-12: $(Get-SecretFingerprint $AdminPassword))." 'Gray'
    $AdminPasswordHash = New-BcryptHash $AdminPassword
    $adminHashSql = $AdminPasswordHash.Replace("'", "''")
    $setAdminPasswordSql = @"
DECLARE @adminRoleId INT = (SELECT TOP 1 id FROM dbo.roles WHERE name = N'Administrador' ORDER BY id);

IF @adminRoleId IS NOT NULL
BEGIN
    UPDATE dbo.roles
    SET is_active = 1,
        deleted_at = NULL,
        updated_at = SYSDATETIME()
    WHERE id = @adminRoleId;
END

UPDATE dbo.users
SET password_hash = N'$adminHashSql',
    role_id = COALESCE(@adminRoleId, role_id),
    is_active = 1,
    deleted_at = NULL,
    updated_at = SYSDATETIME()
WHERE username = N'admin';

IF @@ROWCOUNT = 0
BEGIN
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

    Invoke-SqlcmdChecked -Arguments ($sqlArgs + @('-d', $DbName, '-Q', $setAdminPasswordSql, '-b')) -FailureMessage 'Failed to set initial admin user password.' | Out-Null

    $storedAdminHashRows = Invoke-SqlcmdChecked `
        -Arguments ($sqlArgs + @('-d', $DbName, '-Q', "SET NOCOUNT ON; SELECT password_hash FROM dbo.users WHERE username = N'admin';", '-h', '-1', '-W', '-b')) `
        -FailureMessage 'Failed to verify initial admin user password.'
    $storedAdminHash = @($storedAdminHashRows | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ } | Select-Object -First 1)
    if (-not (Test-BcryptHash $AdminPassword $storedAdminHash)) {
        Write-Log "ERROR: Initial admin user password was written, but bcrypt verification did not match." 'Red'
        exit 1
    }
    Write-Log "Initial admin user password ready and verified." 'Green'
}

# --- Step 6: Run migrations ---------------------------------------------------
Write-Log "=== Step 5: Migrations ===" 'Cyan'
$migrateScript = Join-Path $ScriptDir 'run-migrations.ps1'
if (Test-Path $migrateScript) {
    try {
        & $migrateScript -SqlcmdPath $sqlcmd -DbHost '127.0.0.1' -DbPassword $DbPassword -DbName $DbName -MigrationsDir $MigrationsDir
    } catch {
        Write-Log "Migration step failed: $($_.Exception.Message)" 'Red'
        exit 1
    }
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
