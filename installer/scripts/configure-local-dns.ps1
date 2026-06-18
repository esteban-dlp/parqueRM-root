#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures ParqueRM as the authoritative DNS server for its local name.

.DESCRIPTION
    Writes the CoreDNS configuration, authoritative hosts record, detected
    network metadata, and the router/DHCP setup guide. It does not change
    application secrets, database credentials, or JWT values.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string]$ServerIp = '',
    [string]$CanonicalHost = 'parque.rm.home.arpa',
    [string[]]$LegacyAliases = @('parque.rm.local', 'parquerm.local')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configDir = Join-Path $InstallDir 'config'
$logDir = Join-Path $InstallDir 'logs\network'
$coreFilePath = Join-Path $configDir 'Corefile'
$dnsHostsPath = Join-Path $configDir 'dns-hosts'
$networkConfigPath = Join-Path $configDir 'dns-network.json'
$centralConfigPath = Join-Path $configDir 'parquerm.config.json'
$guidePath = Join-Path $InstallDir 'NETWORK-DNS-SETUP.html'
$textGuidePath = Join-Path $InstallDir 'NETWORK-DNS-SETUP.txt'
$logPath = Join-Path $logDir 'dns-config.log'

foreach ($dir in @($configDir, $logDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Write-Log([string]$Message, [string]$Level = 'INFO') {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logPath -Value $line -Encoding utf8
    Write-Host $line
}

function Test-Ipv4([string]$Value) {
    $parsed = $null
    return [System.Net.IPAddress]::TryParse($Value, [ref]$parsed) -and
        $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
}

function Get-ActiveNetwork {
    param([string]$PreferredIp)

    $candidates = @()
    foreach ($address in @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.'
        })) {
        $adapter = Get-NetAdapter -InterfaceIndex $address.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $adapter -or $adapter.Status -ne 'Up') { continue }

        $route = Get-NetRoute `
            -InterfaceIndex $address.InterfaceIndex `
            -AddressFamily IPv4 `
            -DestinationPrefix '0.0.0.0/0' `
            -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric |
            Select-Object -First 1
        if (-not $route) { continue }

        $ipInterface = Get-NetIPInterface `
            -InterfaceIndex $address.InterfaceIndex `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue
        $metric = if ($ipInterface) { [int]$ipInterface.InterfaceMetric } else { 9999 }

        $candidates += [PSCustomObject]@{
            IP = $address.IPAddress
            PrefixLength = [int]$address.PrefixLength
            InterfaceIndex = [int]$address.InterfaceIndex
            Adapter = $adapter.Name
            Description = $adapter.InterfaceDescription
            MacAddress = $adapter.MacAddress
            Gateway = $route.NextHop
            Metric = $metric
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PreferredIp)) {
        $preferred = $candidates | Where-Object { $_.IP -eq $PreferredIp } | Select-Object -First 1
        if ($preferred) { return $preferred }
    }

    return $candidates | Sort-Object Metric, Adapter | Select-Object -First 1
}

function Get-UpstreamDnsServers {
    param(
        [int]$InterfaceIndex,
        [string]$LocalServerIp
    )

    $servers = @()
    $dnsInfo = Get-DnsClientServerAddress `
        -InterfaceIndex $InterfaceIndex `
        -AddressFamily IPv4 `
        -ErrorAction SilentlyContinue
    if ($dnsInfo) {
        $servers += @($dnsInfo.ServerAddresses)
    }

    if ($servers.Count -eq 0 -and (Test-Path $networkConfigPath)) {
        try {
            $previous = Get-Content $networkConfigPath -Raw | ConvertFrom-Json
            if ($previous.upstreamDns) { $servers += @($previous.upstreamDns) }
        } catch {
            Write-Log "No se pudo leer la configuracion DNS anterior: $($_.Exception.Message)" 'WARN'
        }
    }

    $servers = @($servers |
        Where-Object {
            (Test-Ipv4 $_) -and
            $_ -ne $LocalServerIp -and
            $_ -ne '127.0.0.1' -and
            $_ -ne '0.0.0.0'
        } |
        Select-Object -Unique)

    if ($servers.Count -eq 0) {
        $servers = @('1.1.1.1', '1.0.0.1')
        Write-Log 'No se detectaron DNS upstream utilizables; se usara Cloudflare como respaldo.' 'WARN'
    }
    return $servers
}

function Html([AllowNull()][string]$Value) {
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

if (-not [string]::IsNullOrWhiteSpace($ServerIp) -and -not (Test-Ipv4 $ServerIp)) {
    throw "ServerIp no es una IPv4 valida: $ServerIp"
}

$network = Get-ActiveNetwork -PreferredIp $ServerIp
if (-not $network) {
    throw 'No se encontro un adaptador LAN activo con gateway IPv4.'
}
if ([string]::IsNullOrWhiteSpace($ServerIp)) {
    $ServerIp = $network.IP
}
if ($network.IP -ne $ServerIp) {
    throw "La IP indicada ($ServerIp) no pertenece a un adaptador LAN activo con gateway."
}

$hostNames = @(@($CanonicalHost) + @($LegacyAliases)) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim().ToLowerInvariant() } |
    Select-Object -Unique
$CanonicalHost = $hostNames[0]
$upstreamDns = @(Get-UpstreamDnsServers -InterfaceIndex $network.InterfaceIndex -LocalServerIp $ServerIp)
$normalizedHostsPath = $dnsHostsPath -replace '\\', '/'

"$ServerIp $($hostNames -join ' ')" |
    Out-File -FilePath $dnsHostsPath -Encoding ascii -NoNewline

$coreFile = @"
.:53 {
    errors
    log
    hosts $normalizedHostsPath {
        ttl 60
        reload 5s
        fallthrough
    }
    forward . $($upstreamDns -join ' ') {
        policy sequential
        health_check 5s
    }
    cache 30
}
"@
$coreFile | Out-File -FilePath $coreFilePath -Encoding ascii -NoNewline

$networkConfig = [ordered]@{
    canonicalHost = $CanonicalHost
    legacyAliases = @($hostNames | Select-Object -Skip 1)
    serverIp = $ServerIp
    prefixLength = $network.PrefixLength
    adapter = $network.Adapter
    adapterDescription = $network.Description
    interfaceIndex = $network.InterfaceIndex
    macAddress = $network.MacAddress
    gateway = $network.Gateway
    upstreamDns = @($upstreamDns)
    dnsPort = 53
    guidePath = $guidePath
    configuredAt = (Get-Date).ToString('s')
} 
$networkConfig | ConvertTo-Json -Depth 4 |
    Out-File -FilePath $networkConfigPath -Encoding utf8 -NoNewline

if (Test-Path $centralConfigPath) {
    try {
        $central = Get-Content $centralConfigPath -Raw | ConvertFrom-Json
        $central | Add-Member -NotePropertyName dnsServerIp -NotePropertyValue $ServerIp -Force
        $central | Add-Member -NotePropertyName dnsCanonicalHost -NotePropertyValue $CanonicalHost -Force
        $central | Add-Member -NotePropertyName routerSetupGuide -NotePropertyValue $guidePath -Force
        $central | Add-Member -NotePropertyName routerSetupRequired -NotePropertyValue $true -Force
        if ($central.ports) {
            $central.ports | Add-Member -NotePropertyName dns -NotePropertyValue 53 -Force
        }
        $central | ConvertTo-Json -Depth 6 |
            Out-File -FilePath $centralConfigPath -Encoding utf8 -NoNewline
    } catch {
        Write-Log "No se pudo ampliar parquerm.config.json: $($_.Exception.Message)" 'WARN'
    }
}

$routerUrl = if (Test-Ipv4 $network.Gateway) { "http://$($network.Gateway)" } else { '' }
$htmlCanonical = Html $CanonicalHost
$htmlServerIp = Html $ServerIp
$htmlMac = Html $network.MacAddress
$htmlGateway = Html $network.Gateway
$htmlAdapter = Html $network.Adapter
$htmlRouterUrl = Html $routerUrl
$htmlUpstreams = Html ($upstreamDns -join ', ')
$htmlUrl = Html "http://$CanonicalHost"

$guide = @"
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Configurar DNS de red - ParqueRM</title>
  <style>
    :root { color-scheme: light; font-family: "Segoe UI", Arial, sans-serif; }
    body { margin: 0; color: #17201c; background: #f4f6f5; }
    header { background: #145c3f; color: white; padding: 28px 24px; }
    header div, main { max-width: 900px; margin: 0 auto; }
    h1 { margin: 0 0 8px; font-size: 28px; letter-spacing: 0; }
    h2 { margin-top: 30px; font-size: 20px; letter-spacing: 0; }
    p, li { line-height: 1.55; }
    main { padding: 24px; }
    .summary { background: white; border: 1px solid #d5ddd8; border-radius: 6px; overflow: hidden; }
    .row { display: grid; grid-template-columns: 220px 1fr; border-bottom: 1px solid #e2e7e4; }
    .row:last-child { border-bottom: 0; }
    .label, .value { padding: 12px 14px; overflow-wrap: anywhere; }
    .label { font-weight: 600; background: #eef3f0; }
    code { font-family: Consolas, monospace; background: #edf1ef; padding: 2px 5px; }
    .warning { border-left: 4px solid #c98300; padding: 12px 14px; background: #fff8e8; }
    .ok { border-left: 4px solid #17834f; padding: 12px 14px; background: #edf9f2; }
    a.button { display: inline-block; padding: 10px 14px; color: white; background: #145c3f; border-radius: 5px; text-decoration: none; font-weight: 600; }
    @media (max-width: 620px) { .row { grid-template-columns: 1fr; } .label { padding-bottom: 4px; } }
  </style>
</head>
<body>
  <header><div>
    <h1>DNS de red para ParqueRM</h1>
    <p>Configuracion unica del router para que computadoras y telefonos abran <strong>$htmlUrl</strong>.</p>
  </div></header>
  <main>
    <div class="warning">
      El servidor DNS ya queda instalado en esta computadora. Aun debe configurar el DHCP del router; un programa dentro del servidor no puede cambiar de forma segura el DNS de los demas dispositivos.
    </div>

    <h2>Valores detectados</h2>
    <div class="summary">
      <div class="row"><div class="label">Nombre publico</div><div class="value"><code>$htmlCanonical</code></div></div>
      <div class="row"><div class="label">IP que debe reservar</div><div class="value"><code>$htmlServerIp</code></div></div>
      <div class="row"><div class="label">MAC del servidor</div><div class="value"><code>$htmlMac</code></div></div>
      <div class="row"><div class="label">Gateway / router</div><div class="value"><code>$htmlGateway</code></div></div>
      <div class="row"><div class="label">Adaptador</div><div class="value">$htmlAdapter</div></div>
      <div class="row"><div class="label">DNS externos reenviados</div><div class="value">$htmlUpstreams</div></div>
    </div>

    <h2>1. Reserve la IP del servidor</h2>
    <p>En el router, busque <strong>Address Reservation</strong>, <strong>DHCP Reservation</strong> o <strong>Reserva de direcciones</strong>. Asocie la MAC <code>$htmlMac</code> con la IP <code>$htmlServerIp</code>.</p>

    <h2>2. Entregue ParqueRM como DNS por DHCP</h2>
    <p>En la configuracion DHCP de la LAN, establezca:</p>
    <ul>
      <li>DNS principal: <code>$htmlServerIp</code></li>
      <li>DNS secundario: dejar vacio</li>
    </ul>
    <p class="warning">No coloque Cloudflare, Google u otro DNS publico como secundario. Algunos dispositivos lo usarian directamente y responderian que <code>$htmlCanonical</code> no existe.</p>

    <h2>TP-Link</h2>
    <p>Normalmente se encuentra en <strong>Advanced &gt; Network &gt; DHCP Server</strong>. La reserva suele estar en <strong>Advanced &gt; Network &gt; DHCP Server &gt; Address Reservation</strong>. Los nombres cambian ligeramente segun el modelo.</p>
    <p><a class="button" href="$htmlRouterUrl">Abrir administracion del router</a></p>

    <h2>3. Renueve la red de los clientes</h2>
    <p>Desconecte y vuelva a conectar el Wi-Fi, o ejecute <code>ipconfig /renew</code> en Windows. Luego abra <code>$htmlUrl</code>.</p>

    <h2>4. Valide</h2>
    <p>Desde el menu Inicio de ParqueRM ejecute <strong>Validar DNS de red</strong>. Tambien puede comprobar en Windows:</p>
    <p><code>nslookup $htmlCanonical $htmlServerIp</code></p>
    <p><code>nslookup $htmlCanonical</code></p>
    <div class="ok">La primera consulta valida el servidor ParqueRM. La segunda confirma que el router ya entrega ese DNS a los clientes.</div>
  </main>
</body>
</html>
"@
$guide | Out-File -FilePath $guidePath -Encoding utf8 -NoNewline

$textGuide = @"
PARQUERM - CONFIGURACION DNS DE RED
===================================

URL publica: http://$CanonicalHost
IP reservada del servidor: $ServerIp
MAC del servidor: $($network.MacAddress)
Gateway/router: $($network.Gateway)

1. Reserve $ServerIp para la MAC $($network.MacAddress).
2. En DHCP configure DNS principal = $ServerIp.
3. Deje el DNS secundario vacio.
4. Renueve DHCP en los clientes.
5. Ejecute "Validar DNS de red" y abra http://$CanonicalHost.
"@
$textGuide | Out-File -FilePath $textGuidePath -Encoding utf8 -NoNewline

Write-Log "CoreDNS configurado: $CanonicalHost -> $ServerIp" 'OK'
Write-Log "Upstream DNS: $($upstreamDns -join ', ')" 'OK'
Write-Log "Guia del router: $guidePath" 'OK'

