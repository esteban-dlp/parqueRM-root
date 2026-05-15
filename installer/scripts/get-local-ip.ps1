#Requires -Version 5.1
<#
.SYNOPSIS
    Detects the primary IPv4 LAN address of this machine.

.DESCRIPTION
    Excludes loopback (127.*), APIPA (169.254.*), Docker/WSL/Hyper-V virtual adapters,
    and disconnected adapters. Returns the best candidate IP, or lists multiple if found.

.PARAMETER Silent
    If set, outputs only the IP address (no decorative text). Useful when called from other scripts.

.OUTPUTS
    String -- the selected LAN IPv4 address.
#>
param(
    [switch]$Silent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Adapter name patterns that are typically virtual/irrelevant
$VirtualPatterns = @(
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

function Test-IsVirtual([string]$adapterName) {
    foreach ($pattern in $VirtualPatterns) {
        if ($adapterName -like "*$pattern*") { return $true }
    }
    return $false
}

# Gather all connected adapters with valid IPv4 addresses
$candidates = @()

$adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.PrefixOrigin -ne 'WellKnown' -and        # exclude loopback
        $_.IPAddress -notmatch '^127\.' -and          # loopback range
        $_.IPAddress -notmatch '^169\.254\.' -and     # APIPA
        $_.SuffixOrigin -ne 'Random'                  # exclude random assignments
    }

foreach ($addr in $adapters) {
    $iface = Get-NetAdapter -InterfaceIndex $addr.InterfaceIndex -ErrorAction SilentlyContinue
    if ($null -eq $iface) { continue }
    if ($iface.Status -ne 'Up') { continue }
    if (Test-IsVirtual $iface.Name) { continue }
    if (Test-IsVirtual $iface.InterfaceDescription) { continue }

    $candidates += [PSCustomObject]@{
        IP          = $addr.IPAddress
        Adapter     = $iface.Name
        Description = $iface.InterfaceDescription
        LinkSpeed   = $iface.LinkSpeed
    }
}

if ($candidates.Count -eq 0) {
    Write-Error "No valid LAN IPv4 address found. Check network adapters."
    exit 1
}

if ($candidates.Count -eq 1) {
    if (-not $Silent) {
        Write-Host "Detected LAN IP: $($candidates[0].IP)  (adapter: $($candidates[0].Adapter))" -ForegroundColor Cyan
    }
    return $candidates[0].IP
}

# Multiple candidates -- prefer wired (Ethernet) over wireless
$wired = $candidates | Where-Object { $_.Description -notmatch 'Wi-Fi|Wireless|802\.11|WLAN' }
if ($wired.Count -eq 1) {
    if (-not $Silent) {
        Write-Host "Multiple adapters found. Selected wired: $($wired[0].IP)  (adapter: $($wired[0].Adapter))" -ForegroundColor Cyan
    }
    return $wired[0].IP
}

# Show all options and ask (or just return first when Silent)
if (-not $Silent) {
    Write-Host "`nMultiple LAN IPs found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host "  [$($i+1)] $($candidates[$i].IP)  -- $($candidates[$i].Adapter)" -ForegroundColor White
    }
    Write-Host ""
    $choice = Read-Host "Select IP number (default: 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $candidates.Count) { $index = 0 }
    Write-Host "Selected: $($candidates[$index].IP)" -ForegroundColor Cyan
    return $candidates[$index].IP
} else {
    return $candidates[0].IP
}
