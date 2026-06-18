#Requires -Version 5.1
<#
.SYNOPSIS
    Shows the current running status of ParqueRM services and LAN access URLs.

.PARAMETER InstallDir
    ParqueRM installation root. Default: C:\ParqueRM
#>
param(
    [string]$InstallDir = 'C:\ParqueRM'
)

function Get-SvcStatus([string]$name) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc)                     { return 'No instalado', 'Red' }
    if ($svc.Status -eq 'Running')     { return 'Corriendo',    'Green' }
    if ($svc.Status -eq 'Stopped')     { return 'Detenido',     'Yellow' }
    return $svc.Status.ToString(), 'Gray'
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

        $metric = 0
        $ipInterface = Get-NetIPInterface -InterfaceIndex $addr.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($null -ne $ipInterface) { $metric = $ipInterface.InterfaceMetric }

        $addresses += [PSCustomObject]@{
            IP = $addr.IPAddress
            PrefixLength = [int]$addr.PrefixLength
            Adapter = $adapter.Name
            Description = $adapter.InterfaceDescription
            Metric = $metric
            IsApipa = ($addr.IPAddress -match '^169\.254\.')
            IsWifi = ($adapter.InterfaceDescription -match 'Wi-Fi|Wireless|802\.11|WLAN' -or $adapter.Name -match 'Wi-Fi|Wireless|802\.11|WLAN')
        }
    }

    $nonApipa = @($addresses | Where-Object { -not $_.IsApipa })
    if ($nonApipa.Count -gt 0) { $addresses = $nonApipa }

    return @($addresses |
        Sort-Object IsApipa, @{ Expression = { if ($_.IsWifi) { 1 } else { 0 } } }, Metric, IP |
        Select-Object -Property IP, PrefixLength, Adapter, Description, Metric -Unique)
}

function Test-TcpPort([int]$port) {
    $result = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($result) { return 'Escuchando', 'Green' }
    return 'Sin respuesta', 'Red'
}

function Test-UdpEndpoint([int]$port) {
    $endpoint = Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($endpoint) { return 'Activo', 'Green' }
    return 'No detectado', 'Yellow'
}

function Get-FirewallRuleState([string]$DisplayName) {
    $rule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $rule) { return 'No encontrada', 'Yellow' }
    if ($rule.Enabled -eq 'True' -and $rule.Action -eq 'Allow') { return 'Permitida', 'Green' }
    return "Existe ($($rule.Enabled)/$($rule.Action))", 'Yellow'
}

function Test-Health([string]$Url) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5 -Headers @{ 'Cache-Control' = 'no-cache' }
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
            return "HTTP $($response.StatusCode)", 'Red', $null
        }
        $body = $response.Content | ConvertFrom-Json
        if ($body.app -ne 'ParqueRM') { return 'Respuesta inesperada', 'Yellow', $body }
        return "OK version=$($body.version) instance=$($body.instanceId)", 'Green', $body
    } catch {
        return "Error: $($_.Exception.Message)", 'Red', $null
    }
}

$backendStatus, $backendColor = Get-SvcStatus 'ParqueRMBackend'
$frontendStatus, $frontendColor = Get-SvcStatus 'ParqueRMFrontend'
$localNameStatus, $localNameColor = Get-SvcStatus 'ParqueRMLocalName'
$legacyDnsStatus, $legacyDnsColor = Get-SvcStatus 'ParqueRMDns'

$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
$cfg = $null
$frontendUrl = 'http://parquerm.local'
$backendUrl = 'http://parquerm.local/api'
$swaggerUrl = 'http://parquerm.local/api/docs'
$recommendedUrl = 'http://parquerm.local'
$canonicalHost = 'parquerm.local'
$fallbackUrls = @('http://localhost', 'http://127.0.0.1')
$instanceId = '(no disponible)'
$dbPath = Join-Path $InstallDir 'data\parquerm.db'
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($cfg.frontendUrl) { $frontendUrl = [string]$cfg.frontendUrl }
        if ($cfg.backendUrl) { $backendUrl = [string]$cfg.backendUrl }
        if ($cfg.swaggerUrl) { $swaggerUrl = [string]$cfg.swaggerUrl }
        if ($cfg.recommendedUrl) { $recommendedUrl = [string]$cfg.recommendedUrl }
        if ($cfg.canonicalHost) { $canonicalHost = [string]$cfg.canonicalHost }
        if ($cfg.fallbackUrls) { $fallbackUrls = @($cfg.fallbackUrls) }
        if ($cfg.instanceId) { $instanceId = [string]$cfg.instanceId }
        if ($cfg.dbPath) { $dbPath = [string]$cfg.dbPath }
    } catch {}
}
$dbStatus = if (Test-Path $dbPath) { 'Lista' } else { 'No encontrada' }
$dbColor = if (Test-Path $dbPath) { 'Green' } else { 'Red' }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Estado de ParqueRM" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Backend        : " -NoNewline -ForegroundColor White
Write-Host $backendStatus -ForegroundColor $backendColor
Write-Host "  Frontend/Caddy : " -NoNewline -ForegroundColor White
Write-Host $frontendStatus -ForegroundColor $frontendColor
Write-Host "  Local Name     : " -NoNewline -ForegroundColor White
Write-Host $localNameStatus -ForegroundColor $localNameColor
Write-Host "  SQLite DB      : " -NoNewline -ForegroundColor White
Write-Host "$dbStatus ($dbPath)" -ForegroundColor $dbColor
if (Get-Service -Name 'ParqueRMDns' -ErrorAction SilentlyContinue) {
    Write-Host "  DNS legado     : " -NoNewline -ForegroundColor White
    Write-Host $legacyDnsStatus -ForegroundColor $legacyDnsColor
}
Write-Host "  Instance ID    : " -NoNewline -ForegroundColor White
Write-Host $instanceId -ForegroundColor Cyan

Write-Host ""
Write-Host "  Principal:" -ForegroundColor Yellow
Write-Host "    $recommendedUrl" -ForegroundColor Green
Write-Host "  API same-origin:" -ForegroundColor Yellow
Write-Host "    $backendUrl" -ForegroundColor Cyan
Write-Host "  Swagger:" -ForegroundColor Yellow
Write-Host "    $swaggerUrl" -ForegroundColor Cyan

if ($fallbackUrls.Count -gt 0) {
    Write-Host ""
    Write-Host "  Fallbacks:" -ForegroundColor Yellow
    foreach ($url in $fallbackUrls) {
        Write-Host "    $url" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Puertos y firewall" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$p80status, $p80color = Test-TcpPort 80
$p3000status, $p3000color = Test-TcpPort 3000
$udp5353Status, $udp5353Color = Test-UdpEndpoint 5353
$udp47880Status, $udp47880Color = Test-UdpEndpoint 47880
$fw80Status, $fw80Color = Get-FirewallRuleState 'ParqueRM Caddy TCP 80'
$fw5353Status, $fw5353Color = Get-FirewallRuleState 'ParqueRM mDNS UDP 5353'
$fw47880Status, $fw47880Color = Get-FirewallRuleState 'ParqueRM Discovery UDP 47880'

Write-Host "  TCP 80   (Caddy web)      : " -NoNewline -ForegroundColor White
Write-Host "$p80status / firewall $fw80Status" -ForegroundColor $p80color
Write-Host "  UDP 5353 (mDNS best effort): " -NoNewline -ForegroundColor White
Write-Host "$udp5353Status / firewall $fw5353Status" -ForegroundColor $udp5353Color
Write-Host "  UDP 47880 (Discovery)     : " -NoNewline -ForegroundColor White
Write-Host "$udp47880Status / firewall $fw47880Status" -ForegroundColor $udp47880Color
Write-Host "  TCP 3000 (Backend interno): " -NoNewline -ForegroundColor White
Write-Host "$p3000status; no se abre en firewall por defecto" -ForegroundColor $p3000color

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Red" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
$currentIpInfo = @(Get-CurrentIpv4AddressInfo)
if ($currentIpInfo.Count -gt 0) {
    foreach ($info in $currentIpInfo) {
        Write-Host "  $($info.IP)/$($info.PrefixLength)  $($info.Adapter)" -ForegroundColor Cyan
    }
} else {
    Write-Host "  No se detecto IP LAN util." -ForegroundColor Yellow
}

foreach ($hostName in @($canonicalHost, 'parque.rm.local') | Select-Object -Unique) {
    Write-Host "  Resolucion $hostName : " -NoNewline -ForegroundColor White
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($hostName) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.IPAddressToString }
        if ($resolved) {
            Write-Host ($resolved -join ', ') -ForegroundColor Cyan
        } else {
            Write-Host 'sin IPv4' -ForegroundColor Yellow
        }
    } catch {
        Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Health" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
foreach ($healthUrl in @("$backendUrl/health", 'http://127.0.0.1/api/health') | Select-Object -Unique) {
    $healthStatus, $healthColor, $nullBody = Test-Health $healthUrl
    Write-Host "  $healthUrl : " -NoNewline -ForegroundColor White
    Write-Host $healthStatus -ForegroundColor $healthColor
}

$clientConfigPath = Join-Path $InstallDir 'config\parquerm-client.json'
if (Test-Path $clientConfigPath) {
    try {
        $clientCfg = Get-Content $clientConfigPath -Raw | ConvertFrom-Json
        if ($clientCfg.conflicts -and @($clientCfg.conflicts).Count -gt 0) {
            Write-Host ""
            Write-Host "============================================================" -ForegroundColor Yellow
            Write-Host "  Advertencia de conflicto" -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Yellow
            foreach ($conflict in @($clientCfg.conflicts)) {
                Write-Host "  $($conflict.ip) instance=$($conflict.instanceId) source=$($conflict.source)" -ForegroundColor Yellow
            }
        }
    } catch {}
}

Write-Host ""
Write-Host "Si parquerm.local no abre desde otra PC, pruebe http://<IP-del-servidor>" -ForegroundColor Yellow
Write-Host "o instale el Modo Solo Cliente en esa PC." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
