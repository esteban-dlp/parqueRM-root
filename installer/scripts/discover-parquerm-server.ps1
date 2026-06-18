#Requires -Version 5.1
<#
.SYNOPSIS
    Discovers the ParqueRM server on the local network.

.DESCRIPTION
    Discovery order:
      1. Preferred/manual IP
      2. Last known IP
      3. Direct mDNS queries for parquerm.local and parque.rm.local
      4. UDP broadcast discovery on port 47880
      5. Fast /24 LAN scan on TCP 80

    Every candidate is accepted only after http://<ip>/api/health returns the
    expected ParqueRM public health payload.
#>
param(
    [string]$PreferredServerIp = '',
    [string]$KnownServerIp = '',
    [string[]]$HostNames = @('parquerm.local', 'parque.rm.local'),
    [int]$HttpPort = 80,
    [int]$MdnsPort = 5353,
    [int]$DiscoveryPort = 47880,
    [int]$MdnsTimeoutMs = 900,
    [int]$UdpTimeoutMs = 1200,
    [int]$ConnectTimeoutMs = 350,
    [int]$HealthTimeoutSec = 3,
    [int]$ScanConcurrency = 48,
    [int]$MaxScanCandidates = 512,
    [switch]$Json,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourcePriority = @{
    preferred = 0
    known = 1
    mdns = 2
    udp = 3
    subnet = 4
}

$candidateMap = @{}

function Write-Status([string]$Message) {
    if (-not $Quiet -and -not $Json) { Write-Host $Message }
}

function ConvertTo-Ipv4OrNull([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Value.Trim(), [ref]$parsed)) { return $null }
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $null }
    return $parsed
}

function Get-HttpAuthority([string]$IpAddress) {
    if ($HttpPort -eq 80) { return $IpAddress }
    return "${IpAddress}:$HttpPort"
}

function Test-ParqueRmServer([string]$IpAddress) {
    $parsed = ConvertTo-Ipv4OrNull $IpAddress
    if ($null -eq $parsed) { return $null }

    $ip = $parsed.IPAddressToString
    $healthUrl = "http://$(Get-HttpAuthority $ip)/api/health"
    try {
        $response = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri $healthUrl `
            -TimeoutSec $HealthTimeoutSec `
            -Headers @{ 'Cache-Control' = 'no-cache' }
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) { return $null }

        $body = $response.Content | ConvertFrom-Json
        if ($body.app -ne 'ParqueRM') { return $null }
        if ([string]::IsNullOrWhiteSpace([string]$body.instanceId)) { return $null }

        return [PSCustomObject]@{
            ip = $ip
            app = [string]$body.app
            status = [string]$body.status
            version = if ($body.version) { [string]$body.version } else { 'unknown' }
            instanceId = [string]$body.instanceId
            healthUrl = $healthUrl
            timestamp = if ($body.timestamp) { [string]$body.timestamp } else { '' }
        }
    } catch {
        return $null
    }
}

function Add-ValidatedCandidate([string]$IpAddress, [string]$Source) {
    $health = Test-ParqueRmServer $IpAddress
    if ($null -eq $health) { return $null }

    $key = "$($health.ip)|$($health.instanceId)"
    if ($candidateMap.ContainsKey($key)) {
        $existing = $candidateMap[$key]
        $sources = @(@($existing.sources) + @($Source) | Select-Object -Unique)
        $existing.sources = @($sources)
        if ($sourcePriority[$Source] -lt $existing.priority) {
            $existing.source = $Source
            $existing.priority = $sourcePriority[$Source]
        }
        return $existing
    }

    $candidate = [PSCustomObject]@{
        ip = $health.ip
        app = $health.app
        status = $health.status
        version = $health.version
        instanceId = $health.instanceId
        healthUrl = $health.healthUrl
        source = $Source
        sources = @($Source)
        priority = $sourcePriority[$Source]
    }
    $candidateMap[$key] = $candidate
    Write-Status "Validated ParqueRM candidate: $($candidate.ip) [$Source] instance=$($candidate.instanceId)"
    return $candidate
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

function Get-LocalIpv4AddressInfo {
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
            InterfaceIndex = [int]$addr.InterfaceIndex
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
        Select-Object -Property IP, PrefixLength, InterfaceIndex, Adapter, Description, Metric, IsApipa, IsWifi -Unique)
}

function Add-Byte([System.Collections.Generic.List[byte]]$List, [int]$Value) {
    [void]$List.Add([byte]($Value -band 0xff))
}

function Add-Bytes([System.Collections.Generic.List[byte]]$List, [byte[]]$Bytes) {
    foreach ($byte in $Bytes) { [void]$List.Add([byte]$byte) }
}

function New-MdnsQuery([string]$Name) {
    $query = New-Object 'System.Collections.Generic.List[byte]'
    Add-Bytes $query ([byte[]](0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0))
    foreach ($label in $Name.Trim('.').Split('.')) {
        $labelBytes = [System.Text.Encoding]::ASCII.GetBytes($label)
        if ($labelBytes.Length -gt 63) { throw "DNS label is too long: $label" }
        Add-Byte $query $labelBytes.Length
        Add-Bytes $query $labelBytes
    }
    Add-Byte $query 0
    Add-Bytes $query ([byte[]](0, 1, 128, 1))
    return $query.ToArray()
}

function Get-UInt16([byte[]]$Packet, [int]$Offset) {
    return ([int]$Packet[$Offset] -shl 8) -bor [int]$Packet[$Offset + 1]
}

function Skip-DnsName([byte[]]$Packet, [ref]$Offset) {
    $cursor = $Offset.Value
    while ($cursor -lt $Packet.Length) {
        $length = [int]$Packet[$cursor]
        if ($length -eq 0) {
            $Offset.Value = $cursor + 1
            return $true
        }
        if (($length -band 0xC0) -eq 0xC0) {
            if ($cursor + 1 -ge $Packet.Length) { return $false }
            $Offset.Value = $cursor + 2
            return $true
        }
        $cursor += $length + 1
    }
    return $false
}

function Get-ARecords([byte[]]$Packet) {
    $records = @()
    if ($Packet.Length -lt 12) { return $records }

    $questionCount = Get-UInt16 $Packet 4
    $answerCount = Get-UInt16 $Packet 6
    $offset = 12

    for ($i = 0; $i -lt $questionCount; $i++) {
        $offsetRef = [ref]$offset
        if (-not (Skip-DnsName $Packet $offsetRef)) { return $records }
        $offset = $offsetRef.Value + 4
        if ($offset -gt $Packet.Length) { return $records }
    }

    for ($i = 0; $i -lt $answerCount; $i++) {
        $offsetRef = [ref]$offset
        if (-not (Skip-DnsName $Packet $offsetRef)) { return $records }
        $offset = $offsetRef.Value
        if ($offset + 10 -gt $Packet.Length) { return $records }

        $recordType = Get-UInt16 $Packet $offset
        $dataLength = Get-UInt16 $Packet ($offset + 8)
        $offset += 10
        if ($offset + $dataLength -gt $Packet.Length) { return $records }

        if ($recordType -eq 1 -and $dataLength -eq 4) {
            $bytes = [byte[]]($Packet[$offset], $Packet[$offset + 1], $Packet[$offset + 2], $Packet[$offset + 3])
            $records += (New-Object System.Net.IPAddress -ArgumentList (, $bytes)).IPAddressToString
        }
        $offset += $dataLength
    }

    return @($records | Select-Object -Unique)
}

function Invoke-MdnsDiscovery([object[]]$LocalAddresses) {
    if ($LocalAddresses.Count -eq 0) { return }

    $multicastEndpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse('224.0.0.251')), $MdnsPort
    foreach ($hostName in $HostNames) {
        $query = New-MdnsQuery $hostName
        $clients = @()
        try {
            foreach ($localInfo in $LocalAddresses) {
                try {
                    $localAddress = [System.Net.IPAddress]::Parse([string]$localInfo.IP)
                    $client = New-Object System.Net.Sockets.UdpClient ([System.Net.Sockets.AddressFamily]::InterNetwork)
                    $client.Client.Bind((New-Object System.Net.IPEndPoint $localAddress, 0))
                    $client.Client.SetSocketOption(
                        [System.Net.Sockets.SocketOptionLevel]::IP,
                        [System.Net.Sockets.SocketOptionName]::MulticastTimeToLive,
                        1)
                    $client.Client.SetSocketOption(
                        [System.Net.Sockets.SocketOptionLevel]::IP,
                        [System.Net.Sockets.SocketOptionName]::MulticastInterface,
                        $localAddress.GetAddressBytes())
                    [void]$client.Send($query, $query.Length, $multicastEndpoint)
                    $clients += $client
                } catch {
                    if ($client) { $client.Close() }
                }
            }

            $deadline = [DateTime]::UtcNow.AddMilliseconds($MdnsTimeoutMs)
            while ([DateTime]::UtcNow -lt $deadline) {
                foreach ($client in $clients) {
                    if ($client.Available -le 0) { continue }
                    $remote = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
                    $packet = $client.Receive([ref]$remote)
                    foreach ($candidate in @(Get-ARecords $packet)) {
                        [void](Add-ValidatedCandidate $candidate 'mdns')
                    }
                }
                Start-Sleep -Milliseconds 50
            }
        } finally {
            foreach ($client in $clients) { $client.Close() }
        }
    }
}

function Convert-IpToUInt32([string]$IpAddress) {
    $bytes = [System.Net.IPAddress]::Parse($IpAddress).GetAddressBytes()
    return ([uint32]$bytes[0] -shl 24) -bor ([uint32]$bytes[1] -shl 16) -bor ([uint32]$bytes[2] -shl 8) -bor [uint32]$bytes[3]
}

function Convert-UInt32ToIp([uint32]$Value) {
    $bytes = [byte[]](
        (($Value -shr 24) -band 0xff),
        (($Value -shr 16) -band 0xff),
        (($Value -shr 8) -band 0xff),
        ($Value -band 0xff)
    )
    return (New-Object System.Net.IPAddress -ArgumentList (, $bytes)).IPAddressToString
}

function Get-DirectedBroadcast([string]$IpAddress, [int]$PrefixLength) {
    $scanPrefix = if ($PrefixLength -ge 24) { $PrefixLength } else { 24 }
    $mask = [uint32]0
    if ($scanPrefix -gt 0) {
        $mask = [uint32]::MaxValue -shl (32 - $scanPrefix)
    }
    $ipNumber = Convert-IpToUInt32 $IpAddress
    $network = $ipNumber -band $mask
    $broadcast = $network -bor (-bnot $mask)
    return Convert-UInt32ToIp ([uint32]$broadcast)
}

function Invoke-UdpDiscovery([object[]]$LocalAddresses) {
    $payload = [System.Text.Encoding]::UTF8.GetBytes('PARQUERM_DISCOVER_V1')
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.UdpClient ([System.Net.Sockets.AddressFamily]::InterNetwork)
        $client.EnableBroadcast = $true
        $client.Client.Bind((New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0))

        $targets = @('255.255.255.255')
        foreach ($localInfo in $LocalAddresses) {
            $targets += Get-DirectedBroadcast ([string]$localInfo.IP) ([int]$localInfo.PrefixLength)
        }
        $targets = @($targets | Select-Object -Unique)

        foreach ($target in $targets) {
            try {
                $endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($target)), $DiscoveryPort
                [void]$client.Send($payload, $payload.Length, $endpoint)
            } catch {
                Write-Status "UDP discovery send failed for ${target}: $($_.Exception.Message)"
            }
        }

        $deadline = [DateTime]::UtcNow.AddMilliseconds($UdpTimeoutMs)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($client.Available -le 0) {
                Start-Sleep -Milliseconds 50
                continue
            }

            $remote = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
            $packet = $client.Receive([ref]$remote)
            try {
                $text = [System.Text.Encoding]::UTF8.GetString($packet)
                $jsonBody = $text | ConvertFrom-Json
                if ($jsonBody.app -ne 'ParqueRM') { continue }
                foreach ($ip in @($jsonBody.ips)) {
                    [void](Add-ValidatedCandidate ([string]$ip) 'udp')
                }
                [void](Add-ValidatedCandidate $remote.Address.IPAddressToString 'udp')
            } catch {
                continue
            }
        }
    } finally {
        if ($client) { $client.Close() }
    }
}

function Get-SubnetScanCandidates([object[]]$LocalAddresses) {
    $candidateAddresses = @()

    foreach ($neighbor in @(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -match '^\d{1,3}(\.\d{1,3}){3}$' -and
            $_.IPAddress -notmatch '^127\.' -and
            $_.State -notin @('Unreachable', 'Incomplete')
        })) {
        $candidateAddresses += $neighbor.IPAddress
    }

    foreach ($localInfo in $LocalAddresses) {
        $localIp = [string]$localInfo.IP
        $prefixLength = [int]$localInfo.PrefixLength
        $scanPrefix = if ($prefixLength -ge 24) { $prefixLength } else { 24 }
        $hostCount = [math]::Pow(2, (32 - $scanPrefix))
        if ($hostCount -gt 256) { $hostCount = 256 }

        $mask = [uint32]::MaxValue -shl (32 - $scanPrefix)
        $network = (Convert-IpToUInt32 $localIp) -band $mask
        $first = [uint32]($network + 1)
        $last = [uint32]($network + [uint32]$hostCount - 2)
        if ($last -lt $first) { continue }

        for ($value = $first; $value -le $last; $value++) {
            $candidate = Convert-UInt32ToIp ([uint32]$value)
            if ($candidate -ne $localIp) { $candidateAddresses += $candidate }
        }
    }

    return @($candidateAddresses |
        Where-Object { $_ -notmatch '^169\.254\.' -or @($LocalAddresses | Where-Object { $_.IP -match '^169\.254\.' }).Count -gt 0 } |
        Select-Object -Unique |
        Select-Object -First $MaxScanCandidates)
}

function Find-OpenTcp80([string[]]$CandidateAddresses) {
    $openAddresses = @()
    $index = 0

    while ($index -lt $CandidateAddresses.Count) {
        $batch = @($CandidateAddresses[$index..([math]::Min($index + $ScanConcurrency - 1, $CandidateAddresses.Count - 1))])
        $index += $batch.Count
        $probes = @()

        foreach ($candidate in $batch) {
            try {
                $client = New-Object System.Net.Sockets.TcpClient
                $task = $client.ConnectAsync($candidate, $HttpPort)
                $probes += [PSCustomObject]@{
                    Address = $candidate
                    Client = $client
                    Task = $task
                }
            } catch {
                if ($client) { $client.Close() }
            }
        }

        $deadline = [DateTime]::UtcNow.AddMilliseconds($ConnectTimeoutMs)
        while ([DateTime]::UtcNow -lt $deadline) {
            if (@($probes | Where-Object { -not $_.Task.IsCompleted }).Count -eq 0) { break }
            Start-Sleep -Milliseconds 20
        }

        foreach ($probe in $probes) {
            try {
                if ($probe.Task.IsCompleted -and
                    -not $probe.Task.IsFaulted -and
                    -not $probe.Task.IsCanceled -and
                    $probe.Client.Connected) {
                    $openAddresses += $probe.Address
                }
            } finally {
                $probe.Client.Close()
            }
        }
    }

    return @($openAddresses | Select-Object -Unique)
}

function Invoke-SubnetDiscovery([object[]]$LocalAddresses) {
    $candidateAddresses = @(Get-SubnetScanCandidates $LocalAddresses)
    if ($candidateAddresses.Count -eq 0) { return }

    Write-Status "Scanning up to $($candidateAddresses.Count) LAN addresses on TCP $HttpPort..."
    $openAddresses = @(Find-OpenTcp80 $candidateAddresses)
    foreach ($candidate in $openAddresses) {
        [void](Add-ValidatedCandidate $candidate 'subnet')
    }
}

function New-DiscoveryResult([string]$Status, [object]$Selected, [object[]]$Candidates, [string]$Message) {
    $conflicts = @()
    $instances = @($Candidates |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.instanceId) -and $_.instanceId -ne 'unknown' } |
        Select-Object -ExpandProperty instanceId -Unique)
    if ($instances.Count -gt 1) {
        $conflicts = @($Candidates | Sort-Object instanceId, ip)
    }

    return [ordered]@{
        status = $Status
        selected = $Selected
        candidates = @($Candidates | Sort-Object priority, ip)
        conflicts = @($conflicts)
        message = $Message
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Resolve-DiscoveryResult([string]$KnownIp) {
    $candidates = @($candidateMap.Values | Sort-Object priority, ip)
    if ($candidates.Count -eq 0) {
        return New-DiscoveryResult 'not_found' $null @() 'No ParqueRM server was found on this network.'
    }

    $instances = @($candidates |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.instanceId) -and $_.instanceId -ne 'unknown' } |
        Select-Object -ExpandProperty instanceId -Unique)

    if ($instances.Count -gt 1) {
        $knownCandidate = $null
        $knownParsed = ConvertTo-Ipv4OrNull $KnownIp
        if ($knownParsed) {
            $knownCandidate = $candidates | Where-Object { $_.ip -eq $knownParsed.IPAddressToString } | Select-Object -First 1
        }

        if ($knownCandidate) {
            return New-DiscoveryResult 'conflict' $knownCandidate $candidates 'Multiple ParqueRM servers were detected. Keeping the last known server because it still responds.'
        }

        return New-DiscoveryResult 'conflict' $null $candidates 'Multiple ParqueRM servers were detected. Not selecting a server automatically.'
    }

    $selected = $candidates | Sort-Object priority, ip | Select-Object -First 1
    return New-DiscoveryResult 'found' $selected $candidates 'ParqueRM server found.'
}

$preferred = ConvertTo-Ipv4OrNull $PreferredServerIp
if ($null -ne $preferred) {
    Write-Status "Checking preferred ParqueRM server: $($preferred.IPAddressToString)"
    $preferredCandidate = Add-ValidatedCandidate $preferred.IPAddressToString 'preferred'
    if ($preferredCandidate) {
        $result = New-DiscoveryResult 'found' $preferredCandidate @($candidateMap.Values) 'Preferred ParqueRM server found.'
        if ($Json) { $result | ConvertTo-Json -Depth 6; exit 0 }
        Write-Output $preferredCandidate.ip
        exit 0
    }
}

$known = ConvertTo-Ipv4OrNull $KnownServerIp
if ($null -ne $known) {
    Write-Status "Checking last known ParqueRM server: $($known.IPAddressToString)"
    [void](Add-ValidatedCandidate $known.IPAddressToString 'known')
}

$localAddresses = @(Get-LocalIpv4AddressInfo)
if ($localAddresses.Count -eq 0) {
    $result = New-DiscoveryResult 'not_found' $null @($candidateMap.Values) 'No active useful IPv4 network interfaces were found.'
    if ($Json) { $result | ConvertTo-Json -Depth 6; exit 1 }
    Write-Error $result.message
    exit 1
}

Write-Status 'Trying mDNS discovery...'
Invoke-MdnsDiscovery $localAddresses

Write-Status "Trying ParqueRM UDP discovery on port $DiscoveryPort..."
Invoke-UdpDiscovery $localAddresses

Write-Status 'Trying fast LAN scan fallback...'
Invoke-SubnetDiscovery $localAddresses

$final = Resolve-DiscoveryResult $KnownServerIp
if ($Json) {
    $final | ConvertTo-Json -Depth 6
    if ($final.status -eq 'found' -or ($final.status -eq 'conflict' -and $null -ne $final.selected)) { exit 0 }
    if ($final.status -eq 'conflict') { exit 2 }
    exit 1
}

if ($final.status -eq 'found' -or ($final.status -eq 'conflict' -and $null -ne $final.selected)) {
    if ($final.status -eq 'conflict') { Write-Warning $final.message }
    Write-Output $final.selected.ip
    exit 0
}

if ($final.status -eq 'conflict') {
    Write-Error $final.message
    exit 2
}

Write-Error $final.message
exit 1
