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

.PARAMETER DbPath
    SQLite database file path. Default: InstallDir\data\parquerm.db.

.PARAMETER JwtSecret
    JWT access token secret. REQUIRED.

.PARAMETER JwtRefreshSecret
    JWT refresh token secret. REQUIRED.
#>
param(
    [string]$InstallDir      = 'C:\ParqueRM',
    [string]$ServerIp        = '',
    [string]$CanonicalHost   = 'parquerm.local',
    [string[]]$AliasHosts    = @('parque.rm.local', 'parque.rm.home.arpa'),
    [int]$FrontendPort       = 80,
    [int]$BackendPort        = 3000,
    [int]$MdnsPort           = 5353,
    [int]$DiscoveryPort      = 47880,
    [string]$DbPath          = '',
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
if ([string]::IsNullOrWhiteSpace($DbPath)) {
    $DbPath = Join-Path $InstallDir 'data\parquerm.db'
}

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

function Read-CentralConfigValue([string]$Path, [string]$Key) {
    if (-not (Test-Path $Path)) { return '' }
    try {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        if ($null -ne $config.$Key) { return [string]$config.$Key }
    } catch {
        Write-Warning "Could not read $Key from ${Path}: $($_.Exception.Message)"
    }
    return ''
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

    return '1.0.7'
}

function Test-IsVirtualAdapterName([string]$AdapterName) {
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { return $false }
    $patterns = @(
        'vEthernet',
        'VMware',
        'VirtualBox',
        'Hyper-V',
        'Docker',
        'VPN',
        'TAP',
        'Tailscale',
        'WireGuard',
        'OpenVPN',
        'ZeroTier',
        'AnyConnect',
        'Nord',
        'Radmin',
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

        # InterfaceMetric lives on Get-NetIPInterface, not Get-NetIPAddress.
        $metric = 0
        $ipInterface = Get-NetIPInterface -InterfaceIndex $addr.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($null -ne $ipInterface) { $metric = $ipInterface.InterfaceMetric }

        $addresses += [PSCustomObject]@{
            IP          = $addr.IPAddress
            Adapter     = $adapter.Name
            Description = $adapter.InterfaceDescription
            Metric      = $metric
        }
    }

    return @($addresses |
        Sort-Object @{ Expression = { if ($_.Description -match 'Wi-Fi|Wireless|802\.11|WLAN') { 1 } else { 0 } } }, Metric, IP |
        Select-Object -ExpandProperty IP -Unique)
}

function Test-LocalHostsEntries([string[]]$HostNames) {
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (-not (Test-Path $hostsPath)) { return $false }

    try {
        $mappedNames = @()
        foreach ($line in @(Get-Content -Path $hostsPath -ErrorAction Stop)) {
            $content = ($line -split '#', 2)[0].Trim()
            if ([string]::IsNullOrWhiteSpace($content)) { continue }

            $tokens = @($content -split '\s+' | Where-Object { $_ })
            if ($tokens.Count -lt 2 -or $tokens[0] -ne '127.0.0.1') { continue }
            $mappedNames += @($tokens | Select-Object -Skip 1 | ForEach-Object { $_.ToLowerInvariant() })
        }

        foreach ($name in $HostNames) {
            if ($mappedNames -notcontains $name.ToLowerInvariant()) { return $false }
        }
        return $true
    } catch {
        Write-Warning "Could not inspect hosts file: $($_.Exception.Message)"
        return $false
    }
}

$envPath = Join-Path $BackendDir '.env'
$centralConfigPath = Join-Path $ConfigDir 'parquerm.config.json'
$InstanceId = ''
if ($PreserveExistingSecrets -and (Test-Path $envPath)) {
    $existingJwtSecret = Read-DotEnvValue $envPath 'JWT_SECRET'
    $existingJwtRefreshSecret = Read-DotEnvValue $envPath 'JWT_REFRESH_SECRET'
    $existingInstanceId = Read-DotEnvValue $envPath 'PARQUERM_INSTANCE_ID'

    if (-not [string]::IsNullOrWhiteSpace($existingJwtSecret)) { $JwtSecret = $existingJwtSecret }
    if (-not [string]::IsNullOrWhiteSpace($existingJwtRefreshSecret)) { $JwtRefreshSecret = $existingJwtRefreshSecret }
    if (-not [string]::IsNullOrWhiteSpace($existingInstanceId)) { $InstanceId = $existingInstanceId }
}

if ([string]::IsNullOrWhiteSpace($InstanceId)) {
    $existingConfigInstanceId = Read-CentralConfigValue $centralConfigPath 'instanceId'
    if (-not [string]::IsNullOrWhiteSpace($existingConfigInstanceId)) {
        $InstanceId = $existingConfigInstanceId
    }
}

if ([string]::IsNullOrWhiteSpace($InstanceId)) {
    $InstanceId = [guid]::NewGuid().ToString('N')
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
$AppVersion = Get-AppVersion
$VisibleAliasHosts = @($LocalHostnames |
    Select-Object -Skip 1 |
    Where-Object { $_ -ne 'parque.rm.home.arpa' })
$AliasUrls = @($VisibleAliasHosts | ForEach-Object { Get-HttpUrl $_ $FrontendPort })
$IpFallbackUrls = @(
    (Get-HttpUrl 'localhost' $FrontendPort),
    (Get-HttpUrl '127.0.0.1' $FrontendPort)
)
foreach ($ip in $CurrentIpv4Addresses) {
    $IpFallbackUrls += (Get-HttpUrl $ip $FrontendPort)
}
$FallbackUrls = @(@($AliasUrls) + @($IpFallbackUrls) | Select-Object -Unique)
$HostsConfigured = Test-LocalHostsEntries $LocalHostnames
if ($HostsConfigured) {
    Write-Host "  [OK] hosts contains 127.0.0.1 -> $($LocalHostnames -join ', ')" -ForegroundColor Green
} else {
    Write-Warning 'The local hosts entries are missing. The dedicated local-name configuration step must repair them.'
}

function ConvertTo-SqliteLiteral([string]$Value) {
    return "'$($Value.Replace("'", "''"))'"
}

function Find-Sqlite {
    $candidates = @(
        (Join-Path $InstallDir 'runtime\sqlite\sqlite3.exe'),
        (Join-Path $PSScriptRoot '..\runtime-cache\sqlite\sqlite3.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }

    $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return ''
}

function Update-ParkConfigSystemLanUrl([string]$SystemLanUrl) {
    $sqlite = Find-Sqlite
    if ([string]::IsNullOrWhiteSpace($sqlite)) {
        Write-Warning "sqlite3.exe not found; park_config.system_lan_url was not updated."
        return
    }
    if (-not (Test-Path $DbPath)) {
        Write-Warning "SQLite database not found at $DbPath; park_config.system_lan_url was not updated."
        return
    }

    $urlLiteral = ConvertTo-SqliteLiteral $SystemLanUrl
    $updateSql = @"
UPDATE park_config
SET system_lan_url = $urlLiteral,
    updated_at = CURRENT_TIMESTAMP
WHERE EXISTS (SELECT 1 FROM park_config);
"@

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $sqlite $DbPath '-batch' $updateSql 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
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
PARQUERM_VERSION=$(ConvertTo-DotEnvValue $AppVersion)
PARQUERM_INSTANCE_ID=$(ConvertTo-DotEnvValue $InstanceId)
DB_TYPE=better-sqlite3
DB_PATH=$(ConvertTo-DotEnvValue $DbPath)
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
    version     = $AppVersion
    instanceId  = $InstanceId
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
    dbType      = 'better-sqlite3'
    dbPath      = $DbPath
    ports       = [ordered]@{
        frontend = $FrontendPort
        backend  = $BackendPort
        mdns     = $MdnsPort
        discovery = $DiscoveryPort
    }
    mdnsHostnames = @($LocalHostnames | Where-Object { $_ -ne 'parque.rm.home.arpa' })
    discoveryPort = $DiscoveryPort
    legacyDnsServerPreserved = [bool](Get-Service -Name 'ParqueRMDns' -ErrorAction SilentlyContinue)
    routerSetupRequired = $false
    primaryFlow = 'lan-offline-local-name'
} | ConvertTo-Json -Depth 4

$centralConfig | Out-File -FilePath $centralConfigPath -Encoding utf8 -NoNewline
Write-Host "  [OK] Central config -> $centralConfigPath" -ForegroundColor Green

# Keep the URL shown in Configuracion del parque aligned with the detected server IP.
Update-ParkConfigSystemLanUrl $FrontendUrl

Write-Host ""
Write-Host "Configuration generated successfully." -ForegroundColor Cyan
Write-Host "  Frontend : $FrontendUrl" -ForegroundColor White
Write-Host "  Backend  : $BackendUrl" -ForegroundColor White
Write-Host "  Swagger  : $SwaggerUrl" -ForegroundColor White
