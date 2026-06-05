#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the ParqueRM production installer (ParqueRM-Setup.exe).

.DESCRIPTION
    Full pipeline:
      1. Validates sibling repos exist
      2. Validates runtime-cache contents (unless -SkipRuntimeValidation)
      3. Cleans previous release output
      4. Builds backend (npm run build) -- unless -SkipNpmInstall
      5. Builds frontend (npm run build) -- unless -SkipNpmInstall
      6. Copies compiled artifacts into release/
      7. Copies runtime-cache into release/runtime/
      8. Generates release metadata from version.json
      9. Compiles Inno Setup installer (unless -SkipInstallerCompile)

.PARAMETER SkipRuntimeValidation
    Do not require runtime-cache files to be present.

.PARAMETER SkipInstallerCompile
    Do not run Inno Setup ISCC.exe. Generates release files only.

.PARAMETER SkipNpmInstall
    Skip 'npm ci' AND 'npm run build'. Use existing dist/ artifacts.
    Artifact copy steps are skipped if dist/ does not exist.

.PARAMETER Clean
    Kept for script compatibility. Release is always cleaned for reproducibility.
#>
[CmdletBinding()]
param(
    [switch]$SkipRuntimeValidation,
    [switch]$SkipInstallerCompile,
    [switch]$SkipNpmInstall,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$InstallerDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RootDir      = Split-Path $InstallerDir -Parent
$ParentDir    = Split-Path $RootDir -Parent
$BackendDir   = Join-Path $ParentDir 'parqueRM-backend'
$FrontendDir  = Join-Path $ParentDir 'parqueRM-frontend'
$RuntimeCache = Join-Path $InstallerDir 'runtime-cache'
$ReleaseDir   = Join-Path $RootDir 'release'

function Log {
    param([string]$msg, [string]$color = 'White')
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor $color
}

function Step {
    param([string]$title)
    Write-Host ''
    Write-Host ('=' * 55) -ForegroundColor DarkCyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host ('=' * 55) -ForegroundColor DarkCyan
}

function SafeRobocopy {
    param([string]$src, [string]$dst)
    if (-not (Test-Path $src)) {
        Log "  [SKIP] Source not found: $src" 'Yellow'
        return
    }
    robocopy $src $dst /E /NFL /NDL /NJH /NJS /XF '.gitkeep' | Out-Null
}

function Stop-NodeProcessesInDirectory {
    param([string]$ProjectDir)

    $projectPrefix = ([IO.Path]::GetFullPath($ProjectDir)).TrimEnd('\') + '\'
    $nodeProcesses = @(
        Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                $_.CommandLine -and
                $_.CommandLine.IndexOf($projectPrefix, [StringComparison]::OrdinalIgnoreCase) -ge 0
            }
    )

    if ($nodeProcesses.Count -eq 0) { return }

    foreach ($proc in $nodeProcesses) {
        Log "  Stopping node.exe PID $($proc.ProcessId) using $ProjectDir" 'Yellow'
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 3
}

function Invoke-NpmCiWithRetry {
    param(
        [string]$ProjectDir,
        [string]$Label
    )

    Stop-NodeProcessesInDirectory $ProjectDir

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Log "  Running: npm ci --prefer-offline" 'Yellow'
        npm ci --prefer-offline
        if ($LASTEXITCODE -eq 0) {
            Log '  [OK] npm ci' 'Green'
            return
        }

        if ($attempt -lt 2) {
            Log "  [WARN] npm ci failed for $Label. Retrying after closing local node.exe processes..." 'Yellow'
            Stop-NodeProcessesInDirectory $ProjectDir
            Start-Sleep -Seconds 5
            continue
        }

        Log "[ERROR] npm ci failed for $Label" 'Red'
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host ('=' * 55) -ForegroundColor Cyan
Write-Host '  ParqueRM Installer Build' -ForegroundColor Cyan
Write-Host ('=' * 55) -ForegroundColor Cyan
Log "Root      : $RootDir" 'Gray'
Log "Backend   : $BackendDir" 'Gray'
Log "Frontend  : $FrontendDir" 'Gray'
Log "Release   : $ReleaseDir" 'Gray'
Log "Flags     : SkipRuntimeValidation=$SkipRuntimeValidation  SkipInstallerCompile=$SkipInstallerCompile  SkipNpmInstall=$SkipNpmInstall" 'Gray'

# ---------------------------------------------------------------------------
# Step 1: Validate sibling repos
# ---------------------------------------------------------------------------
Step 'Step 1/9 -- Validate repos'

foreach ($dir in @($RootDir, $BackendDir, $FrontendDir)) {
    if (-not (Test-Path $dir)) {
        Log "[ERROR] Directory not found: $dir" 'Red'
        Log 'Expected structure:' 'Yellow'
        Log '  [parent]/' 'Yellow'
        Log '    parqueRM-root/' 'Yellow'
        Log '    parqueRM-backend/' 'Yellow'
        Log '    parqueRM-frontend/' 'Yellow'
        exit 1
    }
    Log "  [OK] $dir" 'Green'
}

# ---------------------------------------------------------------------------
# Step 2: Validate runtime-cache
# ---------------------------------------------------------------------------
Step 'Step 2/9 -- Validate runtime-cache'

if ($SkipRuntimeValidation) {
    Log '  [SKIP] -SkipRuntimeValidation passed' 'Yellow'
} else {
    $required = @(
        @{ Path = 'sqlserver-express'; Desc = 'SQL Server Express offline installer (SQLEXPR_x64_ENU.exe or similar)' },
        @{ Path = 'node';             Desc = 'Node.js Windows portable/installer (node.exe or node-vX.X.X-win-x64.zip)' },
        @{ Path = 'caddy';            Desc = 'Caddy Windows binary (caddy.exe)' },
        @{ Path = 'winsw';            Desc = 'WinSW service wrapper (WinSW.exe or WinSW-x64.exe)' }
    )

    $missing = @()
    foreach ($req in $required) {
        $fullPath = Join-Path $RuntimeCache $req.Path
        $hasFiles = (Test-Path $fullPath) -and (
            (Get-ChildItem $fullPath -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -ne '.gitkeep' }).Count -gt 0
        )
        if (-not $hasFiles) {
            $missing += "  MISSING: installer\runtime-cache\$($req.Path)\ -- $($req.Desc)"
            Log "  [MISSING] runtime-cache\$($req.Path)" 'Red'
        } else {
            Log "  [OK] runtime-cache\$($req.Path)" 'Green'
        }
    }

    if ($missing.Count -gt 0) {
        Log '' 'Red'
        Log '[ERROR] Runtime cache is incomplete. Place these files before building:' 'Red'
        $missing | ForEach-Object { Log $_ 'Yellow' }
        Log '' 'Yellow'
        Log 'Run with -SkipRuntimeValidation to build without them.' 'Yellow'
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Step 3: Read version
# ---------------------------------------------------------------------------
Step 'Step 3/9 -- Version'

$versionFile = Join-Path $RootDir 'version.json'
if (-not (Test-Path $versionFile)) {
    Log '  [WARN] version.json not found -- using defaults' 'Yellow'
    $ver = [PSCustomObject]@{ appName = 'ParqueRM'; version = '1.0.0' }
} else {
    $ver = Get-Content $versionFile -Raw | ConvertFrom-Json
}

$buildDate   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$buildNumber = Get-Date -Format 'yyyyMMddHHmm'
$version     = $ver.version
Log "  Version: $version  Build: $buildNumber" 'Cyan'

# ---------------------------------------------------------------------------
# Step 4: Clean + create release/
# ---------------------------------------------------------------------------
Step 'Step 4/9 -- Clean release/'

if (Test-Path $ReleaseDir) {
    Log '  Removing existing release/ ...' 'Yellow'
    Remove-Item $ReleaseDir -Recurse -Force
    Log '  [OK] Removed' 'Green'
}

$releasePaths = @(
    'app\backend', 'app\frontend\dist', 'app\database\init', 'app\database\migrations',
    'app\config', 'app\logs', 'app\tools',
    'runtime\sqlserver-express', 'runtime\node', 'runtime\caddy', 'runtime\winsw', 'runtime\sqlcmd'
)
foreach ($p in $releasePaths) {
    New-Item -ItemType Directory -Path (Join-Path $ReleaseDir $p) -Force | Out-Null
}
Log '  [OK] Release directory structure created' 'Green'

# ---------------------------------------------------------------------------
# Step 5: Build backend
# ---------------------------------------------------------------------------
Step 'Step 5/9 -- Build backend'

if ($SkipNpmInstall) {
    Log '  [SKIP] -SkipNpmInstall: skipping npm ci + npm run build' 'Yellow'
    $backendDistExists = Test-Path (Join-Path $BackendDir 'dist')
    if ($backendDistExists) {
        Log "  [OK] Existing dist/ found at $BackendDir\dist" 'Green'
    } else {
        Log "  [WARN] No dist/ found at $BackendDir\dist -- artifact copy will be skipped" 'Yellow'
    }
} else {
    Push-Location $BackendDir
    try {
        Log "  Working dir: $BackendDir" 'Gray'
        Invoke-NpmCiWithRetry -ProjectDir $BackendDir -Label 'backend'

        Log '  Running: npm run build' 'Yellow'
        npm run build
        if ($LASTEXITCODE -ne 0) { Log '[ERROR] Backend build failed' 'Red'; exit 1 }
        Log '  [OK] Backend built' 'Green'
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Step 6: Build frontend
# ---------------------------------------------------------------------------
Step 'Step 6/9 -- Build frontend'

if ($SkipNpmInstall) {
    Log '  [SKIP] -SkipNpmInstall: skipping npm ci + npm run build' 'Yellow'
    $frontendDistExists = Test-Path (Join-Path $FrontendDir 'dist')
    if ($frontendDistExists) {
        Log "  [OK] Existing dist/ found at $FrontendDir\dist" 'Green'
    } else {
        Log "  [WARN] No dist/ found at $FrontendDir\dist -- artifact copy will be skipped" 'Yellow'
    }
} else {
    Push-Location $FrontendDir
    try {
        Log "  Working dir: $FrontendDir" 'Gray'
        Invoke-NpmCiWithRetry -ProjectDir $FrontendDir -Label 'frontend'

        Log '  Running: npm run build' 'Yellow'
        npm run build
        if ($LASTEXITCODE -ne 0) { Log '[ERROR] Frontend build failed' 'Red'; exit 1 }
        Log '  [OK] Frontend built' 'Green'
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Step 7: Copy artifacts
# ---------------------------------------------------------------------------
Step 'Step 7/9 -- Copy artifacts'

$dstBackend  = Join-Path $ReleaseDir 'app\backend'
$dstFrontend = Join-Path $ReleaseDir 'app\frontend\dist'

# Backend dist
$srcBackendDist = Join-Path $BackendDir 'dist'
if (Test-Path $srcBackendDist) {
    SafeRobocopy $srcBackendDist (Join-Path $dstBackend 'dist')
    $pkgJson = Join-Path $BackendDir 'package.json'
    $pkgLock = Join-Path $BackendDir 'package-lock.json'
    if (Test-Path $pkgJson) { Copy-Item $pkgJson $dstBackend -Force }
    if (Test-Path $pkgLock) { Copy-Item $pkgLock $dstBackend -Force }
    Log '  [OK] Backend dist copied' 'Green'

    $srcNodeModules = Join-Path $BackendDir 'node_modules'
    if (Test-Path $srcNodeModules) {
        Log '  Copying backend node_modules (may take a moment) ...' 'Yellow'
        SafeRobocopy $srcNodeModules (Join-Path $dstBackend 'node_modules')
        Log '  [OK] node_modules copied' 'Green'
    } else {
        Log '  [WARN] node_modules not found -- skipped' 'Yellow'
    }
} else {
    Log "  [SKIP] Backend dist not found ($srcBackendDist)" 'Yellow'
}

# Frontend dist
$srcFrontendDist = Join-Path $FrontendDir 'dist'
if (Test-Path $srcFrontendDist) {
    SafeRobocopy $srcFrontendDist $dstFrontend
    Remove-Item (Join-Path $dstFrontend 'config.json') -ErrorAction SilentlyContinue
    Log '  [OK] Frontend dist copied (config.json excluded -- generated at install time)' 'Green'
} else {
    Log "  [SKIP] Frontend dist not found ($srcFrontendDist)" 'Yellow'
}

# DB init scripts
$srcDbInit = Join-Path $RootDir 'db\init'
if (Test-Path $srcDbInit) {
    SafeRobocopy $srcDbInit (Join-Path $ReleaseDir 'app\database\init')
    Log '  [OK] DB init scripts copied' 'Green'
} else {
    Log '  [WARN] db\init not found -- skipped' 'Yellow'
}

# DB migrations
$srcMigrations = Join-Path $RootDir 'db\migrations'
if (Test-Path $srcMigrations) {
    SafeRobocopy $srcMigrations (Join-Path $ReleaseDir 'app\database\migrations')
    Log '  [OK] DB migrations copied' 'Green'
} else {
    Log '  [INFO] db\migrations not found -- skipped (OK if no migrations yet)' 'Gray'
}

# Installer scripts
SafeRobocopy (Join-Path $InstallerDir 'scripts') (Join-Path $ReleaseDir 'app\tools\installer-scripts')
Log '  [OK] Installer scripts copied' 'Green'

# Templates
SafeRobocopy (Join-Path $InstallerDir 'templates') (Join-Path $ReleaseDir 'app\config\templates')
Log '  [OK] Templates copied' 'Green'

# Tool bat files
$srcTools = Join-Path $InstallerDir 'tools'
if (Test-Path $srcTools) {
    SafeRobocopy $srcTools (Join-Path $ReleaseDir 'app\tools')
    Log '  [OK] Tool bat files copied' 'Green'
} else {
    Log '  [WARN] installer/tools/ not found -- tool bat files skipped' 'Yellow'
}

# Runtime cache
if ($SkipRuntimeValidation) {
    Log '  [SKIP] Runtime cache copy (-SkipRuntimeValidation)' 'Yellow'
} else {
    foreach ($subDir in @('sqlserver-express', 'node', 'caddy', 'winsw', 'sqlcmd')) {
        $src = Join-Path $RuntimeCache $subDir
        $dst = Join-Path $ReleaseDir "runtime\$subDir"
        if (Test-Path $src) {
            SafeRobocopy $src $dst
            Log "  [OK] runtime/$subDir copied" 'Green'
        }
    }
}

# ---------------------------------------------------------------------------
# Step 8: Release metadata
# ---------------------------------------------------------------------------
Step 'Step 8/9 -- Release metadata'

$meta = [ordered]@{
    appName     = if ($ver.appName) { $ver.appName } else { 'ParqueRM' }
    version     = $version
    buildDate   = $buildDate
    buildNumber = $buildNumber
}
$metaJson = $meta | ConvertTo-Json -Depth 2

$metaJson | Out-File (Join-Path $ReleaseDir 'version.json') -Encoding utf8 -NoNewline
if (Test-Path $dstBackend) {
    $metaJson | Out-File (Join-Path $dstBackend 'version.json') -Encoding utf8 -NoNewline
}
Log '  [OK] version.json written' 'Green'

# ---------------------------------------------------------------------------
# Step 9: Compile Inno Setup
# ---------------------------------------------------------------------------
Step 'Step 9/9 -- Inno Setup compile'

if ($SkipInstallerCompile) {
    Log '  [SKIP] -SkipInstallerCompile passed' 'Yellow'
    Write-Host ''
    Write-Host ('=' * 55) -ForegroundColor Green
    Write-Host '  DRY-RUN COMPLETE (no .exe compiled)' -ForegroundColor Green
    Write-Host ('=' * 55) -ForegroundColor Green
    Write-Host "  Release files at : $ReleaseDir" -ForegroundColor Cyan
    Write-Host "  Version          : $version (build $buildNumber)" -ForegroundColor White
    Write-Host ''
    Write-Host '  Skipped steps:' -ForegroundColor Yellow
    if ($SkipNpmInstall)        { Write-Host '    [SKIP] npm ci + npm run build' -ForegroundColor Yellow }
    if ($SkipRuntimeValidation) { Write-Host '    [SKIP] runtime-cache validation + copy' -ForegroundColor Yellow }
    Write-Host '    [SKIP] Inno Setup compile' -ForegroundColor Yellow
    Write-Host ('=' * 55) -ForegroundColor Green
    exit 0
}

$iscc = $null
$isccCandidates = @(
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    'C:\Program Files (x86)\Inno Setup 5\ISCC.exe'
)
foreach ($c in $isccCandidates) { if (Test-Path $c) { $iscc = $c; break } }
if (-not $iscc) {
    $sysIscc = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($sysIscc) { $iscc = $sysIscc.Source }
}

if (-not $iscc) {
    Log '[ERROR] ISCC.exe (Inno Setup compiler) not found.' 'Red'
    Log 'Install Inno Setup 6 from: https://jrsoftware.org/isinfo.php' 'Yellow'
    Log 'Or run with -SkipInstallerCompile to generate release files only.' 'Yellow'
    exit 1
}

$issFile = Join-Path $InstallerDir 'ParqueRM-Setup.iss'
if (-not (Test-Path $issFile)) {
    Log "[ERROR] ParqueRM-Setup.iss not found at $issFile" 'Red'
    exit 1
}

$isccArgs = @(
    "/DAppVersion=$version",
    "/DBuildNumber=$buildNumber",
    "/DReleaseDir=$ReleaseDir",
    $issFile
)

Log "  Running: $iscc $isccArgs" 'Yellow'
& $iscc @isccArgs
if ($LASTEXITCODE -ne 0) {
    Log "[ERROR] Inno Setup compilation failed (exit $LASTEXITCODE)" 'Red'
    exit 1
}

$setupExe = Get-ChildItem $ReleaseDir -Filter 'ParqueRM-Setup*.exe' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host ''
Write-Host ('=' * 55) -ForegroundColor Green
Write-Host '  BUILD SUCCESSFUL' -ForegroundColor Green
Write-Host ('=' * 55) -ForegroundColor Green
if ($setupExe) {
    Write-Host "  Installer : $($setupExe.FullName)" -ForegroundColor Cyan
} else {
    Write-Host "  Release   : $ReleaseDir" -ForegroundColor Cyan
}
Write-Host "  Version   : $version (build $buildNumber)" -ForegroundColor White
Write-Host ('=' * 55) -ForegroundColor Green
