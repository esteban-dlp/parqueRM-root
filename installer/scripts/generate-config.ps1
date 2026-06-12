#Requires -Version 5.1
<#
.SYNOPSIS
    Generates all configuration files for a ParqueRM installation.

.DESCRIPTION
    Writes backend .env, frontend config.json, and the central parquerm.config.json.
    Run this during initial install and whenever the server IP changes.

.PARAMETER InstallDir
    Root installation directory. Default: C:\ParqueRM

.PARAMETER ServerIp
    Optional LAN IP of this server. Used only for diagnostics and IP fallback URLs.

.PARAMETER CanonicalHost
    Stable local hostname used as the recommended public URL.

.PARAMETER AliasHosts
    Additional local hostnames that should resolve to this machine.

.PARAMETER FrontendPort
    Port Caddy/frontend listens on. Default: 80

.PARAMETER BackendPort
    Port NestJS backend listens on. Default: 3000

.PARAMETER DbName
    SQL Server database name. Default: ParqueRM

.PARAMETER DbUser
    SQL Server login. Default: sa

.PARAMETER DbPassword
    SQL Server password. REQUIRED.

.PARAMETER JwtSecret
    JWT access token secret. REQUIRED.

.PARAMETER JwtRefreshSecret
    JWT refresh token secret. REQUIRED.
#>
param(
    [string]$InstallDir      = 'C:\ParqueRM',
    [string]$ServerIp        = '',
    [string]$CanonicalHost   = 'parque.rm.local',
    [string[]]$AliasHosts    = @('parquerm.local'),
    [int]$FrontendPort       = 80,
    [int]$BackendPort        = 3000,
    [string]$DbName          = 'ParqueRM',
    [string]$DbUser          = 'sa',
    [string]$DbPassword      = '',
    [string]$JwtSecret       = '',
    [string]$JwtRefreshSecret = '',
    [switch]$PreserveExistingSecrets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Paths --------------------------------------------------------------------
$BackendDir  = Join-Path $InstallDir 'app\backend'
$FrontendDist = Join-Path $InstallDir 'app\frontend\dist'
$ConfigDir   = Join-Path $InstallDir 'config'
$UploadsDir  = Join-Path $InstallDir 'data\uploads'

foreach ($dir in @($BackendDir, $FrontendDist, $ConfigDir, (Join-Path $UploadsDir 'logos'))) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

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

function ConvertTo-DotEnvValue([string]$Value) {
    $escaped = $Value -replace '\\', '\\' -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Get-HttpUrl([string]$HostName, [int]$Port) {
    if ($Port -eq 80) { return "http://$HostName" }
    return "http://${HostName}:$Port"
}

function Get-AppVersion {
    $versionPath = Join-Path $InstallDir 'version.json'
    if (Test-Path $versionPath) {
        try {
            $versionInfo = Get-Content $versionPath -Raw | ConvertFrom-Json
            if ($versionInfo.version) { return [string]$versionInfo.version }
        } catch {
            Write-Warning "Could not read version from ${versionPath}: $($_.Exception.Message)"
        }
    }

    return '1.0.2'
}

function Test-IsVirtualAdapterName([string]$AdapterName) {
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { return $false }
    $patterns = @(
        'vEthernet',
        'VMware',
        'VirtualBox',
        'Hyper-V',
        'WSL',
        'Loopback',
        'Pseudo',
        'Bluetooth',
        'Teredo',
        'ISATAP',
        'Microsoft Wi-Fi Direct',
        'WAN Miniport',
        'Tunnel'
    )
    foreach ($pattern in $patterns) {
        if ($AdapterName -like "*$pattern*") { return $true }
    }
    return $false
}

function Get-CurrentIpv4Addresses {
    $addresses = @()
    $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.PrefixOrigin -ne 'WellKnown' -and
            $_.SuffixOrigin -ne 'Random'
        })

    foreach ($addr in $candidates) {
        $adapter = Get-NetAdapter -InterfaceIndex $addr.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $adapter) { continue }
        if ($adapter.Status -ne 'Up') { continue }
        if (Test-IsVirtualAdapterName $adapter.Name) { continue }
        if (Test-IsVirtualAdapterName $adapter.InterfaceDescription) { continue }

        $addresses += [PSCustomObject]@{
            IP          = $addr.IPAddress
            Adapter     = $adapter.Name
            Description = $adapter.InterfaceDescription
            Metric      = $addr.InterfaceMetric
        }
    }

    return @($addresses |
        Sort-Object @{ Expression = { if ($_.Description -match 'Wi-Fi|Wireless|802\.11|WLAN') { 1 } else { 0 } } }, Metric, IP |
        Select-Object -ExpandProperty IP -Unique)
}

function Set-LocalHostsEntries([string[]]$HostNames) {
    $names = @($HostNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($names.Count -eq 0) { return $false }

    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $marker = '# ParqueRM local URL'
    $escapedNames = (($names | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $hostPattern = "(?i)(^|\s)($escapedNames)(\s|$)"

    try {
        $lines = @()
        if (Test-Path $hostsPath) {
            $lines = @(Get-Content -Path $hostsPath -ErrorAction Stop)
        }

        $kept = @()
        foreach ($line in $lines) {
            if ($line -match [regex]::Escape($marker)) { continue }
            if ($line.TrimStart().StartsWith('#')) {
                $kept += $line
                continue
            }
            if ($line -match $hostPattern) { continue }
            $kept += $line
        }

        $newLine = "127.0.0.1`t$($names -join ' ') $marker"
        Set-Content -Path $hostsPath -Value @($kept + $newLine) -Encoding ASCII -Force
        Write-Host "  [OK] hosts -> 127.0.0.1 $($names -join ', ')" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Could not update hosts file for $($names -join ', '): $($_.Exception.Message)"
        return $false
    }
}

$envPath = Join-Path $BackendDir '.env'
if ($PreserveExistingSecrets -and (Test-Path $envPath)) {
    $existingJwtSecret = Read-DotEnvValue $envPath 'JWT_SECRET'
    $existingJwtRefreshSecret = Read-DotEnvValue $envPath 'JWT_REFRESH_SECRET'

    if (-not [string]::IsNullOrWhiteSpace($existingJwtSecret)) { $JwtSecret = $existingJwtSecret }
    if (-not [string]::IsNullOrWhiteSpace($existingJwtRefreshSecret)) { $JwtRefreshSecret = $existingJwtRefreshSecret }
}

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    Write-Error "DbPassword is required."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($JwtSecret) -or $JwtSecret.Length -lt 16) {
    Write-Error "JwtSecret is required and must be at least 16 characters."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($JwtRefreshSecret) -or $JwtRefreshSecret.Length -lt 16) {
    Write-Error "JwtRefreshSecret is required and must be at least 16 characters."
    exit 1
}

# --- URL assembly -------------------------------------------------------------
$LocalHostnames = @(@($CanonicalHost) + @($AliasHosts)) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim().ToLowerInvariant() } |
    Select-Object -Unique

if ($LocalHostnames.Count -eq 0) {
    Write-Error "At least one local hostname is required."
    exit 1
}

$CanonicalHost = $LocalHostnames[0]
$CurrentIpv4Addresses = @(Get-CurrentIpv4Addresses)
if ([string]::IsNullOrWhiteSpace($ServerIp) -and $CurrentIpv4Addresses.Count -gt 0) {
    $ServerIp = $CurrentIpv4Addresses[0]
}

$FrontendUrl = Get-HttpUrl $CanonicalHost $FrontendPort
$BackendUrl  = "$FrontendUrl/api"
$SwaggerUrl  = "$FrontendUrl/api/docs"
$FrontendApiUrl = '/api'
$AliasUrls = @($LocalHostnames | Select-Object -Skip 1 | ForEach-Object { Get-HttpUrl $_ $FrontendPort })
$IpFallbackUrls = @(
    (Get-HttpUrl 'localhost' $FrontendPort),
    (Get-HttpUrl '127.0.0.1' $FrontendPort)
)
foreach ($ip in $CurrentIpv4Addresses) {
    $IpFallbackUrls += (Get-HttpUrl $ip $FrontendPort)
}
$FallbackUrls = @(@($AliasUrls) + @($IpFallbackUrls) | Select-Object -Unique)
$HostsConfigured = Set-LocalHostsEntries $LocalHostnames

function ConvertTo-SqlLiteral([string]$Value) {
    return "N'$($Value.Replace("'", "''"))'"
}

function Find-Sqlcmd {
    $sqlcmdCmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    if ($sqlcmdCmd) { return $sqlcmdCmd.Source }

    $candidates = @(
        (Join-Path $InstallDir 'runtime\sqlcmd\sqlcmd.exe'),
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }

    return ''
}

function Update-ParkConfigSystemLanUrl([string]$SystemLanUrl) {
    $sqlcmd = Find-Sqlcmd
    if ([string]::IsNullOrWhiteSpace($sqlcmd)) {
        Write-Warning "sqlcmd.exe not found; park_config.system_lan_url was not updated."
        return
    }

    $urlLiteral = ConvertTo-SqlLiteral $SystemLanUrl
    $updateSql = @"
IF OBJECT_ID(N'dbo.park_config', N'U') IS NOT NULL
BEGIN
    UPDATE dbo.park_config
    SET system_lan_url = $urlLiteral,
        updated_at = SYSDATETIME();
END
"@

    $output = & $sqlcmd '-S' '127.0.0.1,1433' '-U' $DbUser '-P' $DbPassword '-d' $DbName '-Q' $updateSql '-b' 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($output) { $output | ForEach-Object { Write-Warning $_ } }
        Write-Error "Failed to update park_config.system_lan_url."
        exit 1
    }

    Write-Host "  [OK] park_config.system_lan_url -> $SystemLanUrl" -ForegroundColor Green
}

# --- Backend .env -------------------------------------------------------------
$envContent = @"
NODE_ENV=production
HOST=0.0.0.0
PORT=$BackendPort
DB_HOST="127.0.0.1"
DB_PORT=1433
DB_USER=$(ConvertTo-DotEnvValue $DbUser)
DB_PASSWORD=$(ConvertTo-DotEnvValue $DbPassword)
DB_NAME=$(ConvertTo-DotEnvValue $DbName)
JWT_SECRET=$(ConvertTo-DotEnvValue $JwtSecret)
JWT_REFRESH_SECRET=$(ConvertTo-DotEnvValue $JwtRefreshSecret)
CORS_ORIGIN=$(ConvertTo-DotEnvValue $FrontendUrl)
PUBLIC_FRONTEND_URL=$(ConvertTo-DotEnvValue $FrontendUrl)
PUBLIC_BACKEND_URL=$(ConvertTo-DotEnvValue $BackendUrl)
UPLOADS_PATH=$(ConvertTo-DotEnvValue $UploadsDir)
"@

$envContent | Out-File -FilePath $envPath -Encoding utf8 -NoNewline
Write-Host "  [OK] Backend .env -> $envPath" -ForegroundColor Green

# --- Frontend config.json -----------------------------------------------------
# Use a same-origin API path so the app keeps working if DHCP changes the LAN IP.
# Caddy proxies /api/* to the local backend service.
$frontendConfig = [ordered]@{ apiUrl = $FrontendApiUrl } | ConvertTo-Json -Depth 2
$frontendConfigPath = Join-Path $FrontendDist 'config.json'
$frontendConfig | Out-File -FilePath $frontendConfigPath -Encoding utf8 -NoNewline
Write-Host "  [OK] Frontend config.json -> $frontendConfigPath" -ForegroundColor Green

# --- Central config JSON ------------------------------------------------------
$centralConfig = [ordered]@{
    appName     = 'ParqueRM'
    version     = Get-AppVersion
    canonicalHost = $CanonicalHost
    localHostnames = @($LocalHostnames)
    serverIp    = $ServerIp
    currentIpv4Addresses = @($CurrentIpv4Addresses)
    recommendedUrl = $FrontendUrl
    frontendUrl = $FrontendUrl
    backendUrl  = $BackendUrl
    swaggerUrl  = $SwaggerUrl
    fallbackUrls = @($FallbackUrls)
    hostsConfigured = [bool]$HostsConfigured
    installDir  = $InstallDir
    dbName      = $DbName
    dbUser      = $DbUser
    ports       = [ordered]@{
        frontend = $FrontendPort
        backend  = $BackendPort
        sqlserver = 1433
    }
} | ConvertTo-Json -Depth 4

$centralConfigPath = Join-Path $ConfigDir 'parquerm.config.json'
$centralConfig | Out-File -FilePath $centralConfigPath -Encoding utf8 -NoNewline
Write-Host "  [OK] Central config -> $centralConfigPath" -ForegroundColor Green

# Keep the URL shown in Configuracion del parque aligned with the detected server IP.
Update-ParkConfigSystemLanUrl $FrontendUrl

Write-Host ""
Write-Host "Configuration generated successfully." -ForegroundColor Cyan
Write-Host "  Frontend : $FrontendUrl" -ForegroundColor White
Write-Host "  Backend  : $BackendUrl" -ForegroundColor White
Write-Host "  Swagger  : $SwaggerUrl" -ForegroundColor White
