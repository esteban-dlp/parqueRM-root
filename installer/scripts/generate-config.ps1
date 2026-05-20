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
    LAN IP of this server. Used in all public URLs.

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

foreach ($dir in @($BackendDir, $FrontendDist, $ConfigDir)) {
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

$envPath = Join-Path $BackendDir '.env'
if ($PreserveExistingSecrets -and (Test-Path $envPath)) {
    $existingJwtSecret = Read-DotEnvValue $envPath 'JWT_SECRET'
    $existingJwtRefreshSecret = Read-DotEnvValue $envPath 'JWT_REFRESH_SECRET'

    if (-not [string]::IsNullOrWhiteSpace($existingJwtSecret)) { $JwtSecret = $existingJwtSecret }
    if (-not [string]::IsNullOrWhiteSpace($existingJwtRefreshSecret)) { $JwtRefreshSecret = $existingJwtRefreshSecret }
}

if ([string]::IsNullOrWhiteSpace($ServerIp)) {
    Write-Error "ServerIp is required."
    exit 1
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
$FrontendUrl = if ($FrontendPort -eq 80) { "http://$ServerIp" } else { "http://${ServerIp}:$FrontendPort" }
$BackendUrl  = "$FrontendUrl/api"
$SwaggerUrl  = "$FrontendUrl/api/docs"
$FrontendApiUrl = '/api'

# --- Backend .env -------------------------------------------------------------
$envContent = @"
NODE_ENV=production
HOST=0.0.0.0
PORT=$BackendPort
DB_HOST="localhost"
DB_PORT=1433
DB_USER=$(ConvertTo-DotEnvValue $DbUser)
DB_PASSWORD=$(ConvertTo-DotEnvValue $DbPassword)
DB_NAME=$(ConvertTo-DotEnvValue $DbName)
JWT_SECRET=$(ConvertTo-DotEnvValue $JwtSecret)
JWT_REFRESH_SECRET=$(ConvertTo-DotEnvValue $JwtRefreshSecret)
CORS_ORIGIN=$(ConvertTo-DotEnvValue $FrontendUrl)
PUBLIC_FRONTEND_URL=$(ConvertTo-DotEnvValue $FrontendUrl)
PUBLIC_BACKEND_URL=$(ConvertTo-DotEnvValue $BackendUrl)
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
    version     = '1.0.0'
    serverIp    = $ServerIp
    frontendUrl = $FrontendUrl
    backendUrl  = $BackendUrl
    swaggerUrl  = $SwaggerUrl
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

Write-Host ""
Write-Host "Configuration generated successfully." -ForegroundColor Cyan
Write-Host "  Frontend : $FrontendUrl" -ForegroundColor White
Write-Host "  Backend  : $BackendUrl" -ForegroundColor White
Write-Host "  Swagger  : $SwaggerUrl" -ForegroundColor White
