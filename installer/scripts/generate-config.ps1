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
    [Parameter(Mandatory)]
    [string]$ServerIp,
    [int]$FrontendPort       = 80,
    [int]$BackendPort        = 3000,
    [string]$DbName          = 'ParqueRM',
    [string]$DbUser          = 'sa',
    [Parameter(Mandatory)]
    [string]$DbPassword,
    [Parameter(Mandatory)]
    [string]$JwtSecret,
    [Parameter(Mandatory)]
    [string]$JwtRefreshSecret
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

# --- URL assembly -------------------------------------------------------------
$FrontendUrl = if ($FrontendPort -eq 80) { "http://$ServerIp" } else { "http://${ServerIp}:$FrontendPort" }
$BackendUrl  = "http://${ServerIp}:$BackendPort/api"
$SwaggerUrl  = "http://${ServerIp}:$BackendPort/api/docs"

# --- Backend .env -------------------------------------------------------------
$envContent = @"
NODE_ENV=production
HOST=0.0.0.0
PORT=$BackendPort
DB_HOST=localhost
DB_PORT=1433
DB_USER=$DbUser
DB_PASSWORD=$DbPassword
DB_NAME=$DbName
JWT_SECRET=$JwtSecret
JWT_REFRESH_SECRET=$JwtRefreshSecret
CORS_ORIGIN=$FrontendUrl
PUBLIC_FRONTEND_URL=$FrontendUrl
PUBLIC_BACKEND_URL=$BackendUrl
"@

$envPath = Join-Path $BackendDir '.env'
$envContent | Out-File -FilePath $envPath -Encoding utf8 -NoNewline
Write-Host "  [OK] Backend .env -> $envPath" -ForegroundColor Green

# --- Frontend config.json -----------------------------------------------------
$frontendConfig = [ordered]@{ apiUrl = $BackendUrl } | ConvertTo-Json -Depth 2
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
