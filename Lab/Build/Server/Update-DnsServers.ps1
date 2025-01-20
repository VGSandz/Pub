# Usage
# Accepts 2 Mandatory parameters, NIC Name and DNS servers to be updated on the specified NIC.
# .\Update-DnsServers.ps1 -NicName "Ethernet0" -DnsServers "8.8.8.8", "8.8.4.4"
# 

param (
    [Parameter(Mandatory = $true)]
    [string]$NicName, # Specify the network adapter name

    [Parameter(Mandatory = $true)]
    [string[]]$DnsServers # Specify one or more DNS server IP addresses
)

# Validate DNS server IPs
if (-not $DnsServers -or $DnsServers.Count -eq 0 -or $DnsServers -contains "") {
    Write-Host "Error: No valid DNS server IP addresses provided." -ForegroundColor Red
    return
}

# Get the network adapter
try {
    $adapter = Get-NetAdapter -Name $NicName -ErrorAction Stop
} catch {
    Write-Host "Error: Network adapter '$NicName' not found or unavailable." -ForegroundColor Red
    return
}

# Ensure the adapter exists
if (-not $adapter) {
    Write-Host "Error: Network adapter '$NicName' does not exist." -ForegroundColor Red
    return
}

# Attempt to update the DNS server IPs
try {
    # Remove current DNS servers
    Set-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ResetServerAddresses -ErrorAction Stop
    Write-Host "Successfully removed current DNS servers from '$NicName'." -ForegroundColor Green

    # Update with new DNS servers
    Set-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ServerAddresses $DnsServers -ErrorAction Stop
    Write-Host "Successfully updated '$NicName' with new DNS servers: $($DnsServers -join ', ')." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to update DNS servers on network adapter '$NicName'. Details: $_" -ForegroundColor Red
    return
}

# Validate the DNS server updates
try {
    $currentDNS = Get-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ErrorAction Stop | Select-Object -ExpandProperty ServerAddresses
    if ($currentDNS -join ',' -eq $DnsServers -join ',') {
        Write-Host "Validation Successful: The DNS servers for '$NicName' are correctly updated to: $($currentDNS -join ', ')." -ForegroundColor Green
    } else {
        Write-Host "Validation Failed: The DNS servers for '$NicName' do not match the expected values. Current DNS: $($currentDNS -join ', '). Expected DNS: $($DnsServers -join ', ')." -ForegroundColor Red
    }
} catch {
    Write-Host "Error: Unable to validate DNS server updates. Details: $_" -ForegroundColor Red
}
