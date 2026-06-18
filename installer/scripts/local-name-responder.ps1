#Requires -Version 5.1
<#
.SYNOPSIS
    Local name and LAN discovery responder for ParqueRM.

.DESCRIPTION
    Answers mDNS A-record queries for parquerm.local and parque.rm.local, sends
    periodic mDNS announcements, and responds to ParqueRM UDP discovery packets
    on port 47880 with the current LAN IPs and instance identity.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string[]]$HostNames = @('parquerm.local', 'parque.rm.local'),
    [int]$MdnsPort = 5353,
    [int]$DiscoveryPort = 47880,
    [int]$TtlSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = Join-Path $InstallDir 'logs\network'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'local-name-responder.log'
$configPath = Join-Path $InstallDir 'config\parquerm.config.json'
$backendEnvPath = Join-Path $InstallDir 'app\backend\.env'
$versionPath = Join-Path $InstallDir 'version.json'
$multicastAddress = [System.Net.IPAddress]::Parse('224.0.0.251')
$multicastEndpoint = New-Object System.Net.IPEndPoint -ArgumentList $multicastAddress, $MdnsPort
$knownNames = @($HostNames |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim().TrimEnd('.').ToLowerInvariant() } |
    Select-Object -Unique)
$lastIpLog = ''
$lastAnnouncementKey = ''
$lastAnnouncementAt = [DateTime]::MinValue

function Write-Log([string]$Message, [string]$Level = 'INFO') {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
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

function Get-ParqueRmMetadata {
    $version = ''
    $instanceId = ''

    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($config.version) { $version = [string]$config.version }
            if ($config.instanceId) { $instanceId = [string]$config.instanceId }
        } catch {
            Write-Log "Could not read central config metadata: $($_.Exception.Message)" 'WARN'
        }
    }

    if ([string]::IsNullOrWhiteSpace($version) -and (Test-Path $versionPath)) {
        try {
            $versionInfo = Get-Content $versionPath -Raw | ConvertFrom-Json
            if ($versionInfo.version) { $version = [string]$versionInfo.version }
        } catch {
            Write-Log "Could not read version metadata: $($_.Exception.Message)" 'WARN'
        }
    }

    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        $instanceId = Read-DotEnvValue $backendEnvPath 'PARQUERM_INSTANCE_ID'
    }
    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = Read-DotEnvValue $backendEnvPath 'PARQUERM_VERSION'
    }

    if ([string]::IsNullOrWhiteSpace($version)) { $version = 'unknown' }
    if ([string]::IsNullOrWhiteSpace($instanceId)) { $instanceId = 'unknown' }

    return [PSCustomObject]@{
        Version = $version
        InstanceId = $instanceId
    }
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
            IP          = $addr.IPAddress
            PrefixLength = [int]$addr.PrefixLength
            Adapter     = $adapter.Name
            Description = $adapter.InterfaceDescription
            Metric      = $metric
            IsApipa     = ($addr.IPAddress -match '^169\.254\.')
            IsWifi      = ($adapter.InterfaceDescription -match 'Wi-Fi|Wireless|802\.11|WLAN' -or $adapter.Name -match 'Wi-Fi|Wireless|802\.11|WLAN')
        }
    }

    $nonApipa = @($addresses | Where-Object { -not $_.IsApipa })
    if ($nonApipa.Count -gt 0) { $addresses = $nonApipa }

    return @($addresses |
        Sort-Object IsApipa, @{ Expression = { if ($_.IsWifi) { 1 } else { 0 } } }, Metric, IP |
        Select-Object -Property IP, PrefixLength, Adapter, Description, Metric -Unique)
}

function Get-CurrentIpv4Addresses {
    return @(Get-CurrentIpv4AddressInfo | Select-Object -ExpandProperty IP -Unique)
}

function Write-IpChangeLog([string[]]$CurrentIps) {
    $ipKey = ($CurrentIps -join ',')
    if ($script:lastIpLog -eq $ipKey) { return }

    if ($CurrentIps.Count -gt 0) {
        Write-Log "Current IPv4 addresses: $($CurrentIps -join ', ')"
    } else {
        Write-Log 'No useful LAN IPv4 address currently available.' 'WARN'
    }
    $script:lastIpLog = $ipKey
}

function Get-UInt16([byte[]]$Bytes, [int]$Offset) {
    return ([int]$Bytes[$Offset] -shl 8) -bor [int]$Bytes[$Offset + 1]
}

function Add-Byte([System.Collections.Generic.List[byte]]$List, [int]$Value) {
    [void]$List.Add([byte]($Value -band 0xff))
}

function Add-Bytes([System.Collections.Generic.List[byte]]$List, [byte[]]$Bytes) {
    foreach ($byte in $Bytes) { [void]$List.Add([byte]$byte) }
}

function Add-UInt16([System.Collections.Generic.List[byte]]$List, [int]$Value) {
    Add-Byte $List (($Value -shr 8) -band 0xff)
    Add-Byte $List ($Value -band 0xff)
}

function Add-UInt32([System.Collections.Generic.List[byte]]$List, [int64]$Value) {
    Add-Byte $List (($Value -shr 24) -band 0xff)
    Add-Byte $List (($Value -shr 16) -band 0xff)
    Add-Byte $List (($Value -shr 8) -band 0xff)
    Add-Byte $List ($Value -band 0xff)
}

function Encode-DnsName([string]$Name) {
    $list = New-Object 'System.Collections.Generic.List[byte]'
    foreach ($label in $Name.TrimEnd('.').Split('.')) {
        if ($label.Length -gt 63) { throw "DNS label too long: $label" }
        Add-Byte $list $label.Length
        Add-Bytes $list ([System.Text.Encoding]::ASCII.GetBytes($label))
    }
    Add-Byte $list 0
    return $list.ToArray()
}

function Read-DnsName([byte[]]$Packet, [ref]$Offset) {
    $labels = @()
    $jumped = $false
    $cursor = $Offset.Value
    $guard = 0

    while ($cursor -lt $Packet.Length -and $guard -lt 64) {
        $guard++
        $length = [int]$Packet[$cursor]
        if ($length -eq 0) {
            $cursor++
            if (-not $jumped) { $Offset.Value = $cursor }
            return ($labels -join '.').ToLowerInvariant()
        }

        if (($length -band 0xC0) -eq 0xC0) {
            if ($cursor + 1 -ge $Packet.Length) { break }
            $pointer = (($length -band 0x3F) -shl 8) -bor [int]$Packet[$cursor + 1]
            if (-not $jumped) { $Offset.Value = $cursor + 2 }
            $cursor = $pointer
            $jumped = $true
            continue
        }

        $cursor++
        if ($cursor + $length -gt $Packet.Length) { break }
        $label = [System.Text.Encoding]::ASCII.GetString($Packet, $cursor, $length)
        $labels += $label
        $cursor += $length
    }

    if (-not $jumped) { $Offset.Value = $cursor }
    return ''
}

function New-AnswerBytes([string]$Name, [string]$IpAddress) {
    $list = New-Object 'System.Collections.Generic.List[byte]'
    Add-Bytes $list (Encode-DnsName $Name)
    Add-UInt16 $list 1
    Add-UInt16 $list 0x8001
    Add-UInt32 $list $TtlSeconds
    Add-UInt16 $list 4
    Add-Bytes $list ([System.Net.IPAddress]::Parse($IpAddress).GetAddressBytes())
    return $list.ToArray()
}

function New-MdnsResponseForNames([byte[]]$Packet, [string[]]$Names, [string[]]$CurrentIps) {
    if ($CurrentIps.Count -eq 0 -or $Names.Count -eq 0) { return $null }

    $answerCount = $Names.Count * $CurrentIps.Count
    $response = New-Object 'System.Collections.Generic.List[byte]'
    if ($null -ne $Packet -and $Packet.Length -ge 2) {
        Add-Byte $response $Packet[0]
        Add-Byte $response $Packet[1]
    } else {
        Add-UInt16 $response 0
    }
    Add-UInt16 $response 0x8400
    Add-UInt16 $response 0
    Add-UInt16 $response $answerCount
    Add-UInt16 $response 0
    Add-UInt16 $response 0

    foreach ($name in $Names) {
        foreach ($ip in $CurrentIps) {
            Add-Bytes $response (New-AnswerBytes $name $ip)
        }
    }

    return $response.ToArray()
}

function New-MdnsResponse([byte[]]$Packet) {
    if ($Packet.Length -lt 12) { return $null }

    $questionCount = Get-UInt16 $Packet 4
    if ($questionCount -le 0) { return $null }

    $offset = 12
    $matchedNames = @()
    for ($i = 0; $i -lt $questionCount; $i++) {
        $refOffset = [ref]$offset
        $queryName = Read-DnsName $Packet $refOffset
        $offset = $refOffset.Value
        if ($offset + 4 -gt $Packet.Length) { break }

        $queryType = Get-UInt16 $Packet $offset
        $offset += 2
        $null = Get-UInt16 $Packet $offset
        $offset += 2

        if (($queryType -eq 1 -or $queryType -eq 255) -and ($knownNames -contains $queryName)) {
            $matchedNames += $queryName
        }
    }

    $matchedNames = @($matchedNames | Select-Object -Unique)
    if ($matchedNames.Count -eq 0) { return $null }

    $currentIps = @(Get-CurrentIpv4Addresses)
    Write-IpChangeLog $currentIps
    return New-MdnsResponseForNames $Packet $matchedNames $currentIps
}

function New-MdnsAnnouncement {
    $currentIps = @(Get-CurrentIpv4Addresses)
    Write-IpChangeLog $currentIps
    return New-MdnsResponseForNames $null $knownNames $currentIps
}

function New-MdnsClient {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.ExclusiveAddressUse = $false
    $udp.Client.SetSocketOption(
        [System.Net.Sockets.SocketOptionLevel]::Socket,
        [System.Net.Sockets.SocketOptionName]::ReuseAddress,
        $true)
    $bindEndpoint = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), $MdnsPort
    $udp.Client.Bind($bindEndpoint)
    $udp.JoinMulticastGroup($multicastAddress)
    return $udp
}

function New-DiscoveryClient {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.ExclusiveAddressUse = $false
    $udp.EnableBroadcast = $true
    $udp.Client.SetSocketOption(
        [System.Net.Sockets.SocketOptionLevel]::Socket,
        [System.Net.Sockets.SocketOptionName]::ReuseAddress,
        $true)
    $bindEndpoint = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), $DiscoveryPort
    $udp.Client.Bind($bindEndpoint)
    return $udp
}

function Test-DiscoveryRequest([byte[]]$Packet) {
    if ($Packet.Length -eq 0) { return $false }
    $text = [System.Text.Encoding]::UTF8.GetString($Packet).Trim()
    if ($text -eq 'PARQUERM_DISCOVER_V1') { return $true }
    try {
        $json = $text | ConvertFrom-Json
        return ($json.app -eq 'ParqueRM' -and $json.type -eq 'discover')
    } catch {
        return $false
    }
}

function New-DiscoveryResponseJson {
    $metadata = Get-ParqueRmMetadata
    $ips = @(Get-CurrentIpv4Addresses)
    Write-IpChangeLog $ips
    $primaryIp = if ($ips.Count -gt 0) { $ips[0] } else { '' }
    $healthUrl = if ($primaryIp) { "http://$primaryIp/api/health" } else { 'http://parquerm.local/api/health' }
    $urls = @($knownNames | ForEach-Object { "http://$_" })
    foreach ($ip in $ips) { $urls += "http://$ip" }

    return ([ordered]@{
        app = 'ParqueRM'
        status = 'ok'
        version = $metadata.Version
        instanceId = $metadata.InstanceId
        hostnames = @($knownNames)
        ips = @($ips)
        port = 80
        healthUrl = $healthUrl
        urls = @($urls | Select-Object -Unique)
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 4 -Compress)
}

function Send-PeriodicAnnouncement([System.Net.Sockets.UdpClient]$MdnsClient) {
    $currentIps = @(Get-CurrentIpv4Addresses)
    $announcementKey = "$($knownNames -join ',')|$($currentIps -join ',')"
    $ageSeconds = ([DateTime]::UtcNow - $script:lastAnnouncementAt).TotalSeconds
    if ($announcementKey -eq $script:lastAnnouncementKey -and $ageSeconds -lt 60) { return }

    $announcement = New-MdnsResponseForNames $null $knownNames $currentIps
    if ($null -eq $announcement) { return }

    [void]$MdnsClient.Send($announcement, $announcement.Length, $multicastEndpoint)
    $script:lastAnnouncementKey = $announcementKey
    $script:lastAnnouncementAt = [DateTime]::UtcNow
    Write-Log "Announced mDNS names: $($knownNames -join ', ')"
}

if ($knownNames.Count -eq 0) {
    Write-Log 'No hostnames configured for local-name responder.' 'ERROR'
    exit 1
}

Write-Log "Starting ParqueRM local-name responder for: $($knownNames -join ', ')"
Write-Log "mDNS UDP $MdnsPort, discovery UDP $DiscoveryPort"

while ($true) {
    $mdnsClient = $null
    $discoveryClient = $null
    try {
        $mdnsClient = New-MdnsClient
        $discoveryClient = New-DiscoveryClient
        Write-Log "Listening on UDP $MdnsPort multicast $multicastAddress and UDP $DiscoveryPort"

        while ($true) {
            Send-PeriodicAnnouncement $mdnsClient

            while ($mdnsClient.Available -gt 0) {
                $remoteEndpoint = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), 0
                $packet = $mdnsClient.Receive([ref]$remoteEndpoint)
                $response = New-MdnsResponse $packet
                if ($null -eq $response) { continue }

                [void]$mdnsClient.Send($response, $response.Length, $multicastEndpoint)
                if ($remoteEndpoint.Address -and $remoteEndpoint.Port -gt 0) {
                    [void]$mdnsClient.Send($response, $response.Length, $remoteEndpoint)
                }
            }

            while ($discoveryClient.Available -gt 0) {
                $remoteEndpoint = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), 0
                $packet = $discoveryClient.Receive([ref]$remoteEndpoint)
                if (-not (Test-DiscoveryRequest $packet)) { continue }

                $json = New-DiscoveryResponseJson
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                [void]$discoveryClient.Send($bytes, $bytes.Length, $remoteEndpoint)
                Write-Log "Discovery response sent to $($remoteEndpoint.Address):$($remoteEndpoint.Port)"
            }

            Start-Sleep -Milliseconds 50
        }
    } catch {
        Write-Log "local-name responder error: $($_.Exception.Message)" 'ERROR'
        if ($mdnsClient) { $mdnsClient.Close() }
        if ($discoveryClient) { $discoveryClient.Close() }
        Start-Sleep -Seconds 30
    }
}
