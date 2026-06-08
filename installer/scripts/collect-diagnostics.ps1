#Requires -Version 5.1
<#
.SYNOPSIS
    Collects ParqueRM installation diagnostics for offline support.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

$ErrorActionPreference = 'SilentlyContinue'

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $InstallDir "diagnostics\$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Write-Section([string]$Path, [string]$Title) {
    Add-Content -Path $Path -Value ''
    Add-Content -Path $Path -Value ('=' * 80)
    Add-Content -Path $Path -Value $Title
    Add-Content -Path $Path -Value ('=' * 80)
}

$report = Join-Path $outDir 'diagnostics.txt'
"ParqueRM Diagnostics - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -Path $report -Encoding utf8
"InstallDir: $InstallDir" | Add-Content -Path $report

Write-Section $report 'Services'
Get-Service ParqueRMBackend,ParqueRMFrontend,MSSQLSERVER,'MSSQL$SQLEXPRESS' |
    Format-Table Status, Name, DisplayName -AutoSize |
    Out-String | Add-Content -Path $report

Write-Section $report 'Ports'
foreach ($port in 80,3000,1433) {
    "Port ${port}: $(Test-NetConnection 127.0.0.1 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue)" |
        Add-Content -Path $report
}

Write-Section $report 'Disk Sector Info'
try {
    fsutil fsinfo sectorinfo C: 2>&1 | Out-String | Add-Content -Path $report
} catch {
    "fsutil failed: $($_.Exception.Message)" | Add-Content -Path $report
}

Write-Section $report 'SQL NVMe Sector Registry Fix'
try {
    Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device' -Name 'ForcedPhysicalSectorSizeInBytes' |
        Format-List |
        Out-String |
        Add-Content -Path $report
} catch {
    'ForcedPhysicalSectorSizeInBytes registry value not found.' | Add-Content -Path $report
}

Write-Section $report 'HTTP Health'
foreach ($url in 'http://127.0.0.1/', 'http://127.0.0.1/api/health', 'http://127.0.0.1/api/health/database') {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10
        "$url -> $($r.StatusCode) $($r.StatusDescription)" | Add-Content -Path $report
        if ($r.Content) { $r.Content | Add-Content -Path $report }
    } catch {
        "$url -> ERROR: $($_.Exception.Message)" | Add-Content -Path $report
    }
}

Write-Section $report 'Config'
$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
if (Test-Path $configPath) {
    Get-Content $configPath -Raw | Add-Content -Path $report
} else {
    "Missing: $configPath" | Add-Content -Path $report
}

Write-Section $report 'Backend .env (secrets redacted)'
$envPath = Join-Path $InstallDir 'app\backend\.env'
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        $_ -replace '^(DB_PASSWORD|JWT_SECRET|JWT_REFRESH_SECRET)=.*$', '$1=<redacted>'
    } | Add-Content -Path $report
} else {
    "Missing: $envPath" | Add-Content -Path $report
}

Write-Section $report 'Latest DB Init Log'
$dbLog = Get-ChildItem (Join-Path $InstallDir 'logs\db-init') -Filter '*.log' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($dbLog) {
    "File: $($dbLog.FullName)" | Add-Content -Path $report
    Get-Content $dbLog.FullName -Tail 200 | Add-Content -Path $report
} else {
    'No db-init logs found.' | Add-Content -Path $report
}

Write-Section $report 'SQL Server ERRORLOG'
$sqlLogRoots = @(
    'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Log',
    'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Log',
    'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Log'
)
foreach ($root in $sqlLogRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Filter 'ERRORLOG*' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 3 |
        ForEach-Object {
            "File: $($_.FullName)" | Add-Content -Path $report
            Get-Content $_.FullName -Tail 160 | Add-Content -Path $report
            Copy-Item -Path $_.FullName -Destination (Join-Path $outDir $_.Name) -Force
        }
    break
}

Write-Section $report 'SQL Setup Bootstrap Logs'
$setupLogRoot = 'C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log'
if (Test-Path $setupLogRoot) {
    Get-ChildItem -Path $setupLogRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('Summary.txt', 'Detail.txt') -or $_.Name -like '*.log' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 8 |
        ForEach-Object {
            "File: $($_.FullName)" | Add-Content -Path $report
            Get-Content $_.FullName -Tail 120 -ErrorAction SilentlyContinue | Add-Content -Path $report
            $safeName = ($_.FullName -replace '^[A-Za-z]:\\', '' -replace '[\\/:*?"<>|]', '_')
            Copy-Item -Path $_.FullName -Destination (Join-Path $outDir $safeName) -Force -ErrorAction SilentlyContinue
        }
} else {
    "SQL setup log root not found: $setupLogRoot" | Add-Content -Path $report
}

Write-Section $report 'Latest Backend Logs'
Get-ChildItem (Join-Path $InstallDir 'logs\backend') -Filter '*.log' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3 |
    ForEach-Object {
        "File: $($_.FullName)" | Add-Content -Path $report
        Get-Content $_.FullName -Tail 120 | Add-Content -Path $report
    }

Write-Section $report 'Latest Frontend Logs'
Get-ChildItem (Join-Path $InstallDir 'logs\frontend') -Filter '*.log' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3 |
    ForEach-Object {
        "File: $($_.FullName)" | Add-Content -Path $report
        Get-Content $_.FullName -Tail 120 | Add-Content -Path $report
    }

Write-Section $report 'Recent ParqueRM Windows Events'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddHours(-6) } |
    Where-Object { $_.Message -match 'ParqueRM|node|caddy|WinSW|MSSQL|SQL Server' } |
    Select-Object -First 50 TimeCreated, ProviderName, Id, Message |
    Format-List |
    Out-String | Add-Content -Path $report

$zipPath = Join-Path $InstallDir "diagnostics\ParqueRM-diagnostics-$stamp.zip"
Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath -Force

Write-Host "Diagnostics written to:"
Write-Host "  $report"
Write-Host "  $zipPath"
