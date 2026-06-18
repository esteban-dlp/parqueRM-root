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

function Test-IsVirtualAdapterName([string]$AdapterName) {
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { return $false }
    $patterns = @(
        'vEthernet', 'VMware', 'VirtualBox', 'Hyper-V', 'Docker', 'VPN',
        'TAP', 'Tailscale', 'WireGuard', 'OpenVPN', 'ZeroTier', 'AnyConnect',
        'Nord', 'Radmin', 'WSL', 'Loopback', 'Pseudo', 'Bluetooth', 'Teredo',
        'ISATAP', 'Microsoft Wi-Fi Direct', 'WAN Miniport', 'Tunnel'
    )
    foreach ($pattern in $patterns) {
        if ($AdapterName -like "*$pattern*") { return $true }
    }
    return $false
}

function Get-CurrentIpv4AddressInfo {
    $addresses = @()
    $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.AddressState -ne 'Duplicate' -and
            $_.PrefixOrigin -ne 'WellKnown' -and
            $_.SuffixOrigin -ne 'Random'
        })

    foreach ($addr in $candidates) {
        $adapter = Get-NetAdapter -InterfaceIndex $addr.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $adapter -or $adapter.Status -ne 'Up') { continue }
        if (Test-IsVirtualAdapterName $adapter.Name) { continue }
        if (Test-IsVirtualAdapterName $adapter.InterfaceDescription) { continue }

        $addresses += [PSCustomObject]@{
            IP = $addr.IPAddress
            PrefixLength = [int]$addr.PrefixLength
            InterfaceIndex = [int]$addr.InterfaceIndex
            Adapter = $adapter.Name
            Description = $adapter.InterfaceDescription
            IsApipa = ($addr.IPAddress -match '^169\.254\.')
        }
    }

    $nonApipa = @($addresses | Where-Object { -not $_.IsApipa })
    if ($nonApipa.Count -gt 0) { $addresses = $nonApipa }
    return @($addresses | Sort-Object IsApipa, IP)
}

function Get-ServiceStatusText([string]$Name) {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return 'NO INSTALADO' }
    return $svc.Status.ToString()
}

function Get-FirewallRuleText([string]$Name) {
    $rule = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $rule) { return 'NO ENCONTRADA' }
    return "Enabled=$($rule.Enabled) Action=$($rule.Action) Profile=$($rule.Profile)"
}

function Test-HealthUrl([string]$Url) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 8 -Headers @{ 'Cache-Control' = 'no-cache' }
        $line = "$Url -> HTTP $($r.StatusCode)"
        if ($r.Content) {
            try {
                $body = $r.Content | ConvertFrom-Json
                $line += " app=$($body.app) status=$($body.status) version=$($body.version) instanceId=$($body.instanceId)"
            } catch {
                $line += " body=$($r.Content.Substring(0, [math]::Min(160, $r.Content.Length)))"
            }
        }
        return $line
    } catch {
        return "$Url -> ERROR: $($_.Exception.Message)"
    }
}

$report = Join-Path $outDir 'diagnostics.txt'
"ParqueRM Diagnostics - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -Path $report -Encoding utf8
"InstallDir: $InstallDir" | Add-Content -Path $report
"ComputerName: $env:COMPUTERNAME" | Add-Content -Path $report

$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
$clientConfigPath = Join-Path $InstallDir 'config\parquerm-client.json'
$cfg = $null
if (Test-Path $configPath) {
    try { $cfg = Get-Content $configPath -Raw | ConvertFrom-Json } catch {}
}

$currentIpInfo = @(Get-CurrentIpv4AddressInfo)
$currentIps = @($currentIpInfo | Select-Object -ExpandProperty IP -Unique)
$canonicalHost = if ($cfg -and $cfg.canonicalHost) { [string]$cfg.canonicalHost } else { 'parquerm.local' }
$localHostNames = @('parquerm.local', 'parque.rm.local')
if ($cfg -and $cfg.mdnsHostnames) { $localHostNames = @($cfg.mdnsHostnames) }
if ($localHostNames -notcontains 'parque.rm.local') { $localHostNames += 'parque.rm.local' }

Write-Section $report 'Quick Summary'
if ($cfg) {
    "Version: $($cfg.version)" | Add-Content -Path $report
    "InstanceId: $($cfg.instanceId)" | Add-Content -Path $report
    "Primary URL: $($cfg.frontendUrl)" | Add-Content -Path $report
    "API URL: $($cfg.backendUrl)" | Add-Content -Path $report
    "Discovery port: $($cfg.discoveryPort)" | Add-Content -Path $report
    if ($cfg.fallbackUrls) {
        "Fallback URLs:" | Add-Content -Path $report
        foreach ($fallbackUrl in @($cfg.fallbackUrls)) { "  - $fallbackUrl" | Add-Content -Path $report }
    }
} else {
    "Config missing: $configPath" | Add-Content -Path $report
}
"LAN IPv4 addresses: $($currentIps -join ', ')" | Add-Content -Path $report
"Services:" | Add-Content -Path $report
foreach ($svcName in 'ParqueRMFrontend', 'ParqueRMBackend', 'ParqueRMLocalName', 'ParqueRMDns') {
    "  $svcName -> $(Get-ServiceStatusText $svcName)" | Add-Content -Path $report
}
"Firewall:" | Add-Content -Path $report
foreach ($ruleName in 'ParqueRM Caddy TCP 80', 'ParqueRM mDNS UDP 5353', 'ParqueRM Discovery UDP 47880', 'ParqueRM Backend TCP 3000', 'ParqueRM DNS UDP 53', 'ParqueRM DNS TCP 53') {
    "  $ruleName -> $(Get-FirewallRuleText $ruleName)" | Add-Content -Path $report
}

Write-Section $report 'Network Interfaces'
Get-NetAdapter -ErrorAction SilentlyContinue |
    Select-Object Name, Status, InterfaceDescription, MacAddress, LinkSpeed, ifIndex |
    Format-Table -AutoSize |
    Out-String | Add-Content -Path $report
"Useful LAN IPv4 addresses:" | Add-Content -Path $report
$currentIpInfo | Format-Table -AutoSize | Out-String | Add-Content -Path $report
"DNS client servers:" | Add-Content -Path $report
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.ServerAddresses.Count -gt 0 } |
    Select-Object InterfaceAlias, InterfaceIndex, ServerAddresses |
    Format-Table -AutoSize |
    Out-String | Add-Content -Path $report

Write-Section $report 'Local Name Resolution'
foreach ($hostName in @($localHostNames | Select-Object -Unique)) {
    try {
        $addrs = [System.Net.Dns]::GetHostAddresses($hostName) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.IPAddressToString }
        "$hostName -> $($addrs -join ', ')" | Add-Content -Path $report
    } catch {
        "$hostName -> ERROR: $($_.Exception.Message)" | Add-Content -Path $report
    }
}
"hosts entries:" | Add-Content -Path $report
$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
if (Test-Path $hostsPath) {
    "hosts attributes: $([System.IO.File]::GetAttributes($hostsPath))" | Add-Content -Path $report
    "hosts last write: $((Get-Item $hostsPath).LastWriteTime.ToString('s'))" | Add-Content -Path $report
}
Get-Content $hostsPath -ErrorAction SilentlyContinue |
    Select-String -Pattern 'parquerm\.local|parque\.rm\.local|parque\.rm\.home\.arpa' |
    Out-String | Add-Content -Path $report

Write-Section $report 'Ports'
foreach ($port in 80, 3000) {
    "TCP ${port}: $(Test-NetConnection 127.0.0.1 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue)" | Add-Content -Path $report
}
foreach ($port in 5353, 47880, 53) {
    "UDP ${port} listeners:" | Add-Content -Path $report
    Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, OwningProcess |
        Format-Table -AutoSize |
        Out-String | Add-Content -Path $report
}

Write-Section $report 'HTTP Health'
$healthUrls = @('http://127.0.0.1/api/health', 'http://127.0.0.1/api/health/database')
if ($cfg) {
    $healthUrls += "$($cfg.backendUrl)/health"
    $healthUrls += "$($cfg.backendUrl)/health/database"
    $healthUrls += "$($cfg.frontendUrl)/"
    if ($cfg.fallbackUrls) {
        foreach ($fallbackUrl in @($cfg.fallbackUrls)) { $healthUrls += "$fallbackUrl/" }
    }
} else {
    $healthUrls += 'http://parquerm.local/api/health'
}
foreach ($url in @($healthUrls | Select-Object -Unique)) {
    Test-HealthUrl $url | Add-Content -Path $report
}

Write-Section $report 'Discovery And Conflicts'
$discoverScript = Join-Path $InstallDir 'tools\installer-scripts\discover-parquerm-server.ps1'
if (Test-Path $discoverScript) {
    $knownIp = if ($currentIps.Count -gt 0) { $currentIps[0] } else { '' }
    $discoverArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $discoverScript, '-Json', '-Quiet')
    if (-not [string]::IsNullOrWhiteSpace($knownIp)) { $discoverArgs += @('-KnownServerIp', $knownIp) }
    $discoveryOutput = @(& powershell.exe @discoverArgs)
    "ExitCode: $LASTEXITCODE" | Add-Content -Path $report
    ($discoveryOutput -join "`n") | Add-Content -Path $report
} else {
    "Missing discovery script: $discoverScript" | Add-Content -Path $report
}
if (Test-Path $clientConfigPath) {
    "Client refresh config:" | Add-Content -Path $report
    Get-Content $clientConfigPath -Raw | Add-Content -Path $report
}

Write-Section $report 'Config'
if (Test-Path $configPath) {
    Get-Content $configPath -Raw | Add-Content -Path $report
} else {
    "Missing: $configPath" | Add-Content -Path $report
}

Write-Section $report 'SQLite Database'
$dbPath = Join-Path $InstallDir 'data\parquerm.db'
if ($cfg -and $cfg.dbPath) { $dbPath = [string]$cfg.dbPath }
if (Test-Path $dbPath) {
    $dbItem = Get-Item $dbPath
    "Path: $dbPath" | Add-Content -Path $report
    "SizeBytes: $($dbItem.Length)" | Add-Content -Path $report
    "LastWriteTime: $($dbItem.LastWriteTime.ToString('s'))" | Add-Content -Path $report
} else {
    "Missing: $dbPath" | Add-Content -Path $report
}

Write-Section $report 'Backend .env (secrets redacted)'
$envPath = Join-Path $InstallDir 'app\backend\.env'
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        $_ -replace '^(JWT_SECRET|JWT_REFRESH_SECRET)=.*$', '$1=<redacted>'
    } | Add-Content -Path $report
} else {
    "Missing: $envPath" | Add-Content -Path $report
}

Write-Section $report 'Legacy CoreDNS Optional Files'
foreach ($legacyPath in @(
    (Join-Path $InstallDir 'config\dns-network.json'),
    (Join-Path $InstallDir 'config\Corefile'),
    (Join-Path $InstallDir 'config\dns-hosts'),
    (Join-Path $InstallDir 'NETWORK-DNS-SETUP.html')
)) {
    if (Test-Path $legacyPath) {
        "Present: $legacyPath" | Add-Content -Path $report
        if ($legacyPath -notlike '*.html') {
            Get-Content $legacyPath -Raw | Add-Content -Path $report
        }
    } else {
        "Missing: $legacyPath" | Add-Content -Path $report
    }
}

Write-Section $report 'Disk Sector Info'
fsutil fsinfo sectorinfo C: 2>&1 | Out-String | Add-Content -Path $report

function Add-LatestLogs([string]$Title, [string]$Path, [string]$Filter, [int]$Count, [int]$Tail) {
    Write-Section $report $Title
    if (-not (Test-Path $Path)) {
        "Missing: $Path" | Add-Content -Path $report
        return
    }
    Get-ChildItem $Path -Filter $Filter -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Count |
        ForEach-Object {
            "File: $($_.FullName)" | Add-Content -Path $report
            Get-Content $_.FullName -Tail $Tail | Add-Content -Path $report
            Copy-Item -Path $_.FullName -Destination (Join-Path $outDir $_.Name) -Force -ErrorAction SilentlyContinue
        }
}

Add-LatestLogs 'Latest DB Init Logs' (Join-Path $InstallDir 'logs\db-init') '*.log' 3 200
Add-LatestLogs 'Latest Backend Logs' (Join-Path $InstallDir 'logs\backend') '*.log' 5 160
Add-LatestLogs 'Latest Frontend Logs' (Join-Path $InstallDir 'logs\frontend') '*.log' 5 160
Add-LatestLogs 'Latest Network Logs' (Join-Path $InstallDir 'logs\network') '*.log' 10 160

Write-Section $report 'Recent ParqueRM Windows Events'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddHours(-6) } |
    Where-Object { $_.Message -match 'ParqueRM|node|caddy|WinSW|SQLite|sqlite|mDNS|5353|47880' } |
    Select-Object -First 60 TimeCreated, ProviderName, Id, Message |
    Format-List |
    Out-String | Add-Content -Path $report

$zipPath = Join-Path $InstallDir "diagnostics\ParqueRM-diagnostics-$stamp.zip"
Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath -Force

Write-Host "Diagnostics written to:"
Write-Host "  $report"
Write-Host "  $zipPath"
