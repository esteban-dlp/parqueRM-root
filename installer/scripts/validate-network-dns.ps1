#Requires -Version 5.1
<#
.SYNOPSIS
    Validates ParqueRM DNS locally and reports whether DHCP appears ready.

.DESCRIPTION
    Direct DNS failures are fatal. A router/DHCP configuration that is still
    pending is reported as a warning and does not fail the installer.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string]$DnsServer = '127.0.0.1',
    [switch]$OpenGuideOnWarning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configDir = Join-Path $InstallDir 'config'
$networkConfigPath = Join-Path $configDir 'dns-network.json'
$centralConfigPath = Join-Path $configDir 'parquerm.config.json'
$validationPath = Join-Path $configDir 'dns-validation.json'
$guidePath = Join-Path $InstallDir 'NETWORK-DNS-SETUP.html'

if (-not (Test-Path $networkConfigPath)) {
    Write-Error "No existe la configuracion DNS: $networkConfigPath"
    exit 1
}

$network = Get-Content $networkConfigPath -Raw | ConvertFrom-Json
$canonicalHost = [string]$network.canonicalHost
$serverIp = [string]$network.serverIp
$expectedIp = $serverIp
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Resolve-Direct {
    param(
        [string]$Name,
        [string]$Server,
        [switch]$Tcp
    )

    $parameters = @{
        Name = $Name
        Server = $Server
        Type = 'A'
        DnsOnly = $true
        ErrorAction = 'Stop'
    }
    if ($Tcp) { $parameters.TcpOnly = $true }
    return @(Resolve-DnsName @parameters |
        Where-Object { $_.Type -eq 'A' -and $_.IPAddress } |
        Select-Object -ExpandProperty IPAddress -Unique)
}

$service = Get-Service -Name 'ParqueRMDns' -ErrorAction SilentlyContinue
if (-not $service) {
    $errors.Add('El servicio ParqueRMDns no esta instalado.')
} elseif ($service.Status -ne 'Running') {
    $errors.Add("El servicio ParqueRMDns no esta corriendo: $($service.Status).")
}

$udpAddresses = @()
$tcpAddresses = @()
$externalAddresses = @()
try {
    $udpAddresses = @(Resolve-Direct -Name $canonicalHost -Server $DnsServer)
    if ($udpAddresses -notcontains $expectedIp) {
        $errors.Add("UDP 53 respondio '$($udpAddresses -join ', ')' en vez de $expectedIp.")
    }
} catch {
    $errors.Add("UDP 53 no resolvio ${canonicalHost}: $($_.Exception.Message)")
}

try {
    $tcpAddresses = @(Resolve-Direct -Name $canonicalHost -Server $DnsServer -Tcp)
    if ($tcpAddresses -notcontains $expectedIp) {
        $errors.Add("TCP 53 respondio '$($tcpAddresses -join ', ')' en vez de $expectedIp.")
    }
} catch {
    $errors.Add("TCP 53 no resolvio ${canonicalHost}: $($_.Exception.Message)")
}

try {
    $externalAddresses = @(Resolve-Direct -Name 'example.com' -Server $DnsServer)
    if ($externalAddresses.Count -eq 0) {
        $errors.Add('CoreDNS no devolvio direcciones para example.com.')
    }
} catch {
    $errors.Add("El reenvio de dominios externos fallo: $($_.Exception.Message)")
}

$activeDnsServers = @()
try {
    $activeIndexes = @(Get-NetRoute `
        -AddressFamily IPv4 `
        -DestinationPrefix '0.0.0.0/0' `
        -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty InterfaceIndex -Unique)
    foreach ($index in $activeIndexes) {
        $activeDnsServers += @(Get-DnsClientServerAddress `
            -InterfaceIndex $index `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty ServerAddresses)
    }
    $activeDnsServers = @($activeDnsServers | Where-Object { $_ } | Select-Object -Unique)
} catch {
    $warnings.Add("No se pudo revisar el DNS recibido por DHCP: $($_.Exception.Message)")
}

$dhcpAppearsConfigured = $activeDnsServers -contains $serverIp
if (-not $dhcpAppearsConfigured) {
    $warnings.Add("Esta computadora todavia no usa $serverIp como DNS. Configure el DHCP del router y renueve la conexion de los clientes.")
}

$result = [ordered]@{
    checkedAt = (Get-Date).ToString('s')
    canonicalHost = $canonicalHost
    expectedIp = $expectedIp
    dnsServerTested = $DnsServer
    serviceStatus = if ($service) { $service.Status.ToString() } else { 'NotInstalled' }
    udpAddresses = @($udpAddresses)
    tcpAddresses = @($tcpAddresses)
    externalForwardingAddresses = @($externalAddresses)
    activeDnsServers = @($activeDnsServers)
    dhcpAppearsConfigured = [bool]$dhcpAppearsConfigured
    errors = @($errors)
    warnings = @($warnings)
}
$result | ConvertTo-Json -Depth 5 |
    Out-File -FilePath $validationPath -Encoding utf8 -NoNewline

Write-Host ''
Write-Host 'Validacion DNS de ParqueRM' -ForegroundColor Cyan
Write-Host "  UDP 53: $($udpAddresses -join ', ')" -ForegroundColor $(if ($udpAddresses -contains $expectedIp) { 'Green' } else { 'Red' })
Write-Host "  TCP 53: $($tcpAddresses -join ', ')" -ForegroundColor $(if ($tcpAddresses -contains $expectedIp) { 'Green' } else { 'Red' })
Write-Host "  Reenvio externo: $($externalAddresses -join ', ')" -ForegroundColor $(if ($externalAddresses.Count -gt 0) { 'Green' } else { 'Red' })
Write-Host "  DNS activos del adaptador: $($activeDnsServers -join ', ')" -ForegroundColor Gray

foreach ($warning in $warnings) {
    Write-Warning $warning
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        Write-Host "  [ERROR] $errorMessage" -ForegroundColor Red
    }
    exit 1
}

if (-not $dhcpAppearsConfigured) {
    Write-Host ''
    Write-Host '  CoreDNS funciona, pero falta configurar el router.' -ForegroundColor Yellow
    Write-Host "  Guia: $guidePath" -ForegroundColor Yellow
    if ($OpenGuideOnWarning -and (Test-Path $guidePath)) {
        Start-Process -FilePath $guidePath
    }
} else {
    Write-Host '  [OK] El adaptador recibe ParqueRM como DNS.' -ForegroundColor Green
}

Write-Host "  Resultado: $validationPath" -ForegroundColor Gray
exit 0

