#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a ParqueRM update package (ParqueRM-Update.zip).

.DESCRIPTION
    Builds backend + frontend, then packages them into:
      release/updates/ParqueRM-Update-vX.X.X.zip

    The update package contains ONLY application files -- no runtimes,
    no .env, no config.json. Safe to deploy without affecting server config.

.PARAMETER SkipNpmInstall
    Skip 'npm ci' before building. Build still runs.

.PARAMETER SkipBuild
    Use existing build artifacts from previous build (skip compile step entirely).

.PARAMETER IncludeNodeModules
    Include backend node_modules in the update package.
    Default: NOT included (updates are for dist-only changes).
    Use only when npm dependencies have changed.
    WARNING: adds hundreds of MB and significantly increases compression time.
#>
[CmdletBinding()]
param(
    [switch]$SkipNpmInstall,
    [switch]$SkipBuild,
    [switch]$IncludeNodeModules
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$InstallerDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RootDir      = Split-Path $InstallerDir -Parent
$ParentDir    = Split-Path $RootDir -Parent
$BackendDir   = Join-Path $ParentDir 'parqueRM-backend'
$FrontendDir  = Join-Path $ParentDir 'parqueRM-frontend'
$ReleaseDir   = Join-Path $RootDir 'release'
$UpdatesDir   = Join-Path $ReleaseDir 'updates'
$StagingDir   = Join-Path $ReleaseDir 'updates-staging'

function Log {
    param([string]$msg, [string]$color = 'White')
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor $color
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
$versionFile = Join-Path $RootDir 'version.json'
$ver = if (Test-Path $versionFile) {
    Get-Content $versionFile -Raw | ConvertFrom-Json
} else {
    [PSCustomObject]@{ version = '1.0.0'; appName = 'ParqueRM' }
}
$version     = $ver.version
$buildDate   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$buildNumber = Get-Date -Format 'yyyyMMddHHmm'

Write-Host ''
Write-Host ('=' * 55) -ForegroundColor Cyan
Write-Host '  ParqueRM Update Package Build' -ForegroundColor Cyan
Write-Host ('=' * 55) -ForegroundColor Cyan
Log "Version    : $version  Build: $buildNumber" 'Gray'
Log "Backend    : $BackendDir" 'Gray'
Log "Frontend   : $FrontendDir" 'Gray'
Log "Flags      : SkipNpmInstall=$SkipNpmInstall  SkipBuild=$SkipBuild" 'Gray'

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
if ($SkipBuild) {
    Log '--- [SKIP] Build step (-SkipBuild) ---' 'Yellow'
    $backendOk  = Test-Path (Join-Path $BackendDir 'dist')
    $frontendOk = Test-Path (Join-Path $FrontendDir 'dist')
    if (-not $backendOk)  { Log "  [WARN] $BackendDir\dist not found -- artifact may be empty" 'Yellow' }
    if (-not $frontendOk) { Log "  [WARN] $FrontendDir\dist not found -- artifact may be empty" 'Yellow' }
} else {
    Log '--- Building backend ---' 'Cyan'
    Push-Location $BackendDir
    try {
        Log "  Working dir: $BackendDir" 'Gray'
        if (-not $SkipNpmInstall) {
            Log '  Running: npm ci --prefer-offline' 'Yellow'
            npm ci --prefer-offline
            if ($LASTEXITCODE -ne 0) { Log '[ERROR] npm ci failed' 'Red'; exit 1 }
            Log '  [OK] npm ci' 'Green'
        }
        Log '  Running: npm run build' 'Yellow'
        npm run build
        if ($LASTEXITCODE -ne 0) { Log '[ERROR] Backend build failed' 'Red'; exit 1 }
        Log '  [OK] Backend built' 'Green'
    } finally { Pop-Location }

    Log '--- Building frontend ---' 'Cyan'
    Push-Location $FrontendDir
    try {
        Log "  Working dir: $FrontendDir" 'Gray'
        if (-not $SkipNpmInstall) {
            Log '  Running: npm ci --prefer-offline' 'Yellow'
            npm ci --prefer-offline
            if ($LASTEXITCODE -ne 0) { Log '[ERROR] npm ci failed' 'Red'; exit 1 }
            Log '  [OK] npm ci' 'Green'
        }
        Log '  Running: npm run build' 'Yellow'
        npm run build
        if ($LASTEXITCODE -ne 0) { Log '[ERROR] Frontend build failed' 'Red'; exit 1 }
        Log '  [OK] Frontend built' 'Green'
    } finally { Pop-Location }
}

# ---------------------------------------------------------------------------
# Stage update package
# ---------------------------------------------------------------------------
Log '--- Staging update package ---' 'Cyan'

if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
$pkg = Join-Path $StagingDir 'ParqueRM-Update'

$dirsToCreate = @('backend\dist', 'frontend', 'database\migrations', 'scripts')
if ($IncludeNodeModules) { $dirsToCreate += 'backend\node_modules' }
foreach ($d in $dirsToCreate) {
    New-Item -ItemType Directory -Path (Join-Path $pkg $d) -Force | Out-Null
}

if (-not $IncludeNodeModules) {
    Log '  [INFO] node_modules NOT included (-IncludeNodeModules to include for dependency updates)' 'Gray'
}

# Backend
$srcBackendDist = Join-Path $BackendDir 'dist'
if (Test-Path $srcBackendDist) {
    robocopy $srcBackendDist (Join-Path $pkg 'backend\dist') /E /NFL /NDL /NJH /NJS | Out-Null
    $pkgJson = Join-Path $BackendDir 'package.json'
    if (Test-Path $pkgJson) { Copy-Item $pkgJson (Join-Path $pkg 'backend') -Force }
    if ($IncludeNodeModules) {
        $srcNodeModules = Join-Path $BackendDir 'node_modules'
        if (Test-Path $srcNodeModules) {
            Log '  Copying node_modules (this takes a few minutes) ...' 'Yellow'
            robocopy $srcNodeModules (Join-Path $pkg 'backend\node_modules') /E /NFL /NDL /NJH /NJS | Out-Null
            Log '  [OK] node_modules included' 'Green'
        }
    }
    Log '  [OK] backend' 'Green'
} else {
    Log "  [SKIP] backend dist not found ($srcBackendDist)" 'Yellow'
}

# Frontend (exclude config.json -- keep server's own config)
$srcFrontendDist = Join-Path $FrontendDir 'dist'
if (Test-Path $srcFrontendDist) {
    robocopy $srcFrontendDist (Join-Path $pkg 'frontend') /E /NFL /NDL /NJH /NJS /XF 'config.json' | Out-Null
    Log '  [OK] frontend' 'Green'
} else {
    Log "  [SKIP] frontend dist not found ($srcFrontendDist)" 'Yellow'
}

# Migrations
$migrSrc = Join-Path $RootDir 'db\migrations'
if (Test-Path $migrSrc) {
    robocopy $migrSrc (Join-Path $pkg 'database\migrations') /E /NFL /NDL /NJH /NJS | Out-Null
    Log '  [OK] migrations' 'Green'
} else {
    Log '  [INFO] No migrations directory found (OK if none yet)' 'Gray'
}

# Scripts
$applyScript   = Join-Path $InstallerDir 'scripts\apply-update.ps1'
$migrScript    = Join-Path $InstallerDir 'scripts\run-migrations.ps1'
if (Test-Path $applyScript) { Copy-Item $applyScript (Join-Path $pkg 'scripts') -Force }
if (Test-Path $migrScript)  { Copy-Item $migrScript  (Join-Path $pkg 'scripts') -Force }
Log '  [OK] scripts' 'Green'

# Version metadata
[ordered]@{
    appName     = if ($ver.appName) { $ver.appName } else { 'ParqueRM' }
    version     = $version
    buildDate   = $buildDate
    buildNumber = $buildNumber
} | ConvertTo-Json -Depth 2 | Out-File (Join-Path $pkg 'version.json') -Encoding utf8 -NoNewline
Log '  [OK] version.json' 'Green'

# ---------------------------------------------------------------------------
# Zip
# ---------------------------------------------------------------------------
Log '--- Compressing ---' 'Cyan'

if (-not (Test-Path $UpdatesDir)) { New-Item -ItemType Directory -Path $UpdatesDir -Force | Out-Null }

$zipName       = "ParqueRM-Update-v$version.zip"
$zipLatest     = 'ParqueRM-Update.zip'
$zipPath       = Join-Path $UpdatesDir $zipName
$zipLatestPath = Join-Path $UpdatesDir $zipLatest

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Log "  Compressing $StagingDir -> $zipPath" 'Gray'
Compress-Archive -Path (Join-Path $StagingDir '*') -DestinationPath $zipPath -CompressionLevel Optimal
Copy-Item $zipPath $zipLatestPath -Force

Remove-Item $StagingDir -Recurse -Force

Write-Host ''
Write-Host ('=' * 55) -ForegroundColor Green
Write-Host '  UPDATE PACKAGE BUILT' -ForegroundColor Green
Write-Host ('=' * 55) -ForegroundColor Green
Write-Host "  Package  : $zipPath" -ForegroundColor Cyan
Write-Host "  Latest   : $zipLatestPath" -ForegroundColor Cyan
Write-Host "  Version  : $version (build $buildNumber)" -ForegroundColor White
if ($SkipBuild) { Write-Host '  [NOTE] Built from existing dist/ artifacts (-SkipBuild)' -ForegroundColor Yellow }
Write-Host ('=' * 55) -ForegroundColor Green
