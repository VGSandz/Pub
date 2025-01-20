# Usage
# Clean up NIC Configuration and set to DHCP.
# .\Configure-NIC.ps1 -Cleanup -NicName "Ethernet0" 
#
# Configure NIC with IP Address, addtional IPs. 
# The parameters are Mandatory
# .\Configure-NIC.ps1 -NicName "HostOnly" -IPAddress "192.168.1.15" -PrefixLength 24 `
# -DNSServers "8.8.8.81", "8.8.4.41" -Gateway "192.168.1.1" `
# -AdditionalIPs "192.168.1.16", "192.168.1.17" -DNSSuffix "example.com", "example.local"

param (
    [Parameter(Mandatory = $false)]
    [switch]$Cleanup, # If specified, remove NIC settings

    [Parameter(Mandatory = $false)]
    [string]$NicName, # Network Interface Name

    [Parameter(Mandatory = $false)]
    [string]$IPAddress, # Primary Static IP Address

    [Parameter(Mandatory = $false)]
    [string[]]$AdditionalIPs = @(), # Additional IP Addresses (optional)

    [Parameter(Mandatory = $false)]
    [string[]]$DNSServers, # DNS Server IPs

    [Parameter(Mandatory = $false)]
    [string]$Gateway, # Gateway IP Address

    [Parameter(Mandatory = $false)]
    [string[]]$DNSSuffix = @(), # DNS Suffix (optional)

    [Parameter(Mandatory = $false)]
    [int]$PrefixLength # Prefix Length for the Primary IP Address
)

# Function to validate the inputs
function Validate-Inputs {
    param (
        [string]$NicName,
        [string]$IPAddress,
        [string[]]$DNSServers,
        [string]$Gateway,
        [int]$PrefixLength
    )

    if ([string]::IsNullOrWhiteSpace($NicName)) {
        Write-Host "Error: NIC name cannot be null or empty." -ForegroundColor Red
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($IPAddress)) {
        Write-Host "Error: Primary IP Address cannot be null or empty." -ForegroundColor Red
        return $false
    }

    if (-not $DNSServers -or $DNSServers.Count -eq 0 -or $DNSServers -contains "") {
        Write-Host "Error: DNS Servers cannot be null or empty." -ForegroundColor Red
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($Gateway)) {
        Write-Host "Error: Gateway cannot be null or empty." -ForegroundColor Red
        return $false
    }

    if ($PrefixLength -lt 1 -or $PrefixLength -gt 32) {
        Write-Host "Error: Prefix length must be between 1 and 32." -ForegroundColor Red
        return $false
    }

    return $true
}

# Function to retrieve network interface
function Get-NetworkInterface {
    param (
        [string]$NicName
    )

    try {
        return Get-NetAdapter -Name $NicName -ErrorAction Stop
    } catch {
        Write-Host "Error: Network interface '$NicName' not found." -ForegroundColor Red
        return $null
    }
}

# Function to remove NIC settings (cleanup)
function Remove-NICSettings {
    param (
        [string]$NicName
    )

    Write-Host "Cleaning up NIC '$NicName' settings..." -ForegroundColor Green

    # Step 1: Set NIC to DHCP
    try {
        Set-NetIPInterface -InterfaceAlias $NicName -Dhcp Enabled -ErrorAction Stop | Out-Null
        Write-Host "NIC '$NicName' set to DHCP." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to set NIC '$NicName' to DHCP. Details: $_" -ForegroundColor Red
    }

    # Step 2: Set DNS to DHCP
    try {
        Set-DnsClientServerAddress -InterfaceAlias $NicName -ResetServerAddresses -ErrorAction Stop | Out-Null
        Write-Host "DNS servers for '$NicName' set to DHCP." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to set DNS servers for '$NicName' to DHCP. Details: $_" -ForegroundColor Red
    }

    # Step 3: Remove DNS Search Suffix
    try {
        Set-DnsClient -InterfaceAlias $NicName -ConnectionSpecificSuffix "" -ErrorAction Stop | Out-Null
        Write-Host "DNS Search Suffix cleared for '$NicName'." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to clear DNS search suffix on '$NicName'. Details: $_" -ForegroundColor Red
    }

    # Step 4: Clear Global DNS Suffix
    try {
        Set-DnsClientGlobalSetting -SuffixSearchList @() -ErrorAction Stop | Out-Null
        Write-Host "Global DNS suffix list cleared." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to clear global DNS suffix list. Details: $_" -ForegroundColor Red
    }
    
    # Step 5: Remove Existing Gateway
    try {
    # Remove the existing default gateway (0.0.0.0/0) if it exists
    $existingGateway = Get-NetRoute -InterfaceAlias $NicName -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
    foreach ($gw in $existingGateway) {
        Remove-NetRoute -InterfaceAlias $NicName -DestinationPrefix "0.0.0.0/0" -NextHop $gw.NextHop -ErrorAction Stop -Confirm:$False | Out-Null
        Write-Host "Removed existing default gateway '$($gw.NextHop)' for NIC '$NicName'." -ForegroundColor Green
    }
} catch {
    Write-Host "Error: Failed to remove existing gateway on NIC '$NicName'. Details: $_" -ForegroundColor Red
    return
}
}

# Function to configure static IP
function Set-StaticIP {
    param (
        [string]$NicName,
        [string]$IPAddress,
        [string]$Gateway,
        [int]$PrefixLength,
        [string[]]$DNSServers,
        [string[]]$AdditionalIPs,
        [string[]]$DNSSuffix
    )

    # Disable DHCP before applying static IP
    try {
        Set-NetIPInterface -InterfaceAlias $NicName -Dhcp Disabled -ErrorAction Stop | Out-Null
        Write-Host "DHCP disabled on '$NicName'." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to disable DHCP on '$NicName'. Details: $_" -ForegroundColor Red
        return
    }

    # Configure primary static IP
    try {
        # Check if the static IP is already configured, if so remove it before applying new one
        $existingIP = Get-NetIPAddress -InterfaceAlias $NicName -IPAddress $IPAddress -ErrorAction SilentlyContinue
        if ($existingIP) {
            Remove-NetIPAddress -InterfaceAlias $NicName -IPAddress $IPAddress -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "Removed existing IP address '$IPAddress' from NIC '$NicName'." -ForegroundColor Green
        }

        New-NetIPAddress -InterfaceAlias $NicName -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop | Out-Null
        Write-Host "Primary static IP address '$IPAddress/$PrefixLength' with gateway '$Gateway' configured on '$NicName'." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to configure primary IP address on '$NicName'. Details: $_" -ForegroundColor Red
        return
    }

    # Configure Additional IPs
    if ($AdditionalIPs -and $AdditionalIPs.Count -gt 0) {
        foreach ($additionalIP in $AdditionalIPs) {
            try {
                # Adding additional IP addresses to the NIC
                New-NetIPAddress -InterfaceAlias $NicName -IPAddress $additionalIP -PrefixLength $PrefixLength -ErrorAction Stop | Out-Null
                Write-Host "Additional static IP address '$additionalIP/$PrefixLength' configured on '$NicName'." -ForegroundColor Green
            } catch {
                Write-Host "Error: Failed to configure additional IP address '$additionalIP'. Details: $_" -ForegroundColor Red
            }
        }
    }

    # Configure DNS servers
    try {
        Set-DnsClientServerAddress -InterfaceAlias $NicName -ServerAddresses $DNSServers -ErrorAction Stop | Out-Null
        Write-Host "DNS servers '$($DNSServers -join ', ' )' configured on '$NicName'." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to configure DNS servers on '$NicName'. Details: $_" -ForegroundColor Red
        return
    }

    # Configure DNS suffix
    if ($DNSSuffix -and $DNSSuffix.Count -gt 0) {
        try {
            Set-DnsClient -InterfaceAlias $NicName -ConnectionSpecificSuffix ($DNSSuffix -join ',') -ErrorAction Stop | Out-Null
            Write-Host "DNS suffix '$($DNSSuffix -join ', ' )' configured on '$NicName'." -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to configure DNS suffix on '$NicName'. Details: $_" -ForegroundColor Red
            return
        }
    }

    # Step 10: Append global DNS suffix search list
    if ($DNSSuffix -and $DNSSuffix.Count -gt 0) {
        try {
            Set-DnsClientGlobalSetting -SuffixSearchList $DNSSuffix -ErrorAction Stop | Out-Null
            Write-Host "Global DNS suffix search list '$($DNSSuffix -join ', ' )' configured." -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to configure global DNS suffix search list. Details: $_" -ForegroundColor Red
            return
        }
    }
}

# Main logic

if ($Cleanup) {
    if (-not $NicName) {
        Write-Host "Error: NIC name is required for cleanup." -ForegroundColor Red
        return
    }
    Remove-NICSettings -NicName $NicName
} else {
    if (-not (Validate-Inputs -NicName $NicName -IPAddress $IPAddress -DNSServers $DNSServers -Gateway $Gateway -PrefixLength $PrefixLength)) {
        return
    }

    $networkInterface = Get-NetworkInterface -NicName $NicName
    if ($networkInterface) {
        Set-StaticIP -NicName $NicName `
            -IPAddress $IPAddress `
            -Gateway $Gateway `
            -PrefixLength $PrefixLength `
            -DNSServers $DNSServers `
            -AdditionalIPs $AdditionalIPs `
            -DNSSuffix $DNSSuffix
    }
}
