#Requires -Version 5.1
<#
.SYNOPSIS
    Lightweight mDNS responder for ParqueRM stable local names.

.DESCRIPTION
    Answers A-record mDNS queries for parque.rm.local and parquerm.local with
    the current non-virtual IPv4 addresses. This gives LAN clients a chance to
    use the stable URL when their OS/network supports multicast DNS.
#>
param(
    [string]$InstallDir = 'C:\ParqueRM',
    [string[]]$HostNames = @('parque.rm.local', 'parquerm.local'),
    [int]$Port = 5353,
    [int]$TtlSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = Join-Path $InstallDir 'logs\network'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'local-name-responder.log'
$multicastAddress = [System.Net.IPAddress]::Parse('224.0.0.251')
$multicastEndpoint = New-Object System.Net.IPEndPoint -ArgumentList $multicastAddress, $Port
$knownNames = @($HostNames |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim().TrimEnd('.').ToLowerInvariant() } |
    Select-Object -Unique)
$lastIpLog = ''

function Write-Log([string]$Message, [string]$Level = 'INFO') {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

function Test-IsVirtualAdapterName([string]$AdapterName) {
    if ([string]::IsNullOrWhiteSpace($AdapterName)) { return $false }
    $patterns = @(
        'vEthernet',
        'VMware',
        'VirtualBox',
        'Hyper-V',
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

function Get-CurrentIpv4Addresses {
    $addresses = @()
    $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.PrefixOrigin -ne 'WellKnown' -and
            $_.SuffixOrigin -ne 'Random'
        })

    foreach ($addr in $candidates) {
        $adapter = Get-NetAdapter -InterfaceIndex $addr.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $adapter) { continue }
        if ($adapter.Status -ne 'Up') { continue }
        if (Test-IsVirtualAdapterName $adapter.Name) { continue }
        if (Test-IsVirtualAdapterName $adapter.InterfaceDescription) { continue }

        $addresses += [PSCustomObject]@{
            IP          = $addr.IPAddress
            Description = $adapter.InterfaceDescription
            Metric      = $addr.InterfaceMetric
        }
    }

    return @($addresses |
        Sort-Object @{ Expression = { if ($_.Description -match 'Wi-Fi|Wireless|802\.11|WLAN') { 1 } else { 0 } } }, Metric, IP |
        Select-Object -ExpandProperty IP -Unique)
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
    $ipKey = ($currentIps -join ',')
    if ($script:lastIpLog -ne $ipKey) {
        if ($currentIps.Count -gt 0) {
            Write-Log "Current IPv4 addresses: $($currentIps -join ', ')"
        } else {
            Write-Log 'No LAN IPv4 address currently available.' 'WARN'
        }
        $script:lastIpLog = $ipKey
    }
    if ($currentIps.Count -eq 0) { return $null }

    $answerCount = $matchedNames.Count * $currentIps.Count
    $response = New-Object 'System.Collections.Generic.List[byte]'
    Add-Byte $response $Packet[0]
    Add-Byte $response $Packet[1]
    Add-UInt16 $response 0x8400
    Add-UInt16 $response 0
    Add-UInt16 $response $answerCount
    Add-UInt16 $response 0
    Add-UInt16 $response 0

    foreach ($name in $matchedNames) {
        foreach ($ip in $currentIps) {
            Add-Bytes $response (New-AnswerBytes $name $ip)
        }
    }

    return $response.ToArray()
}

function New-MdnsClient {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.ExclusiveAddressUse = $false
    $udp.Client.SetSocketOption(
        [System.Net.Sockets.SocketOptionLevel]::Socket,
        [System.Net.Sockets.SocketOptionName]::ReuseAddress,
        $true)
    $bindEndpoint = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), $Port
    $udp.Client.Bind($bindEndpoint)
    $udp.JoinMulticastGroup($multicastAddress)
    return $udp
}

Write-Log "Starting ParqueRM mDNS responder for: $($knownNames -join ', ')"

while ($true) {
    $udpClient = $null
    try {
        $udpClient = New-MdnsClient
        Write-Log "Listening on UDP $Port multicast $multicastAddress"

        while ($true) {
            $remoteEndpoint = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), 0
            $packet = $udpClient.Receive([ref]$remoteEndpoint)
            $response = New-MdnsResponse $packet
            if ($null -eq $response) { continue }

            [void]$udpClient.Send($response, $response.Length, $multicastEndpoint)
            if ($remoteEndpoint.Address -and $remoteEndpoint.Port -gt 0) {
                [void]$udpClient.Send($response, $response.Length, $remoteEndpoint)
            }
        }
    } catch {
        Write-Log "mDNS responder error: $($_.Exception.Message)" 'ERROR'
        if ($udpClient) { $udpClient.Close() }
        Start-Sleep -Seconds 30
    }
}
