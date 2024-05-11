#Single NIC only.
$VMNIC =  Get-NetAdapter

# Network Interface Name (replace with the actual interface name).
$interfaceName = $VMNIC.Name

# Static IP configuration.
$ipAddress = "192.168.6.10"

$subnetMask = "255.255.255.0"
$dnsServers = "192.168.6.10"
$dnsSuffix = "labone.local"

# Get the network interface.
$networkInterface = Get-NetAdapter | Where-Object { $_.Name -eq $interfaceName }

# Set the interface to use a static IP configuration.
$networkInterface | Set-NetIPInterface -Dhcp Disabled

# Set the IP address and subnet mask.
$networkInterface | New-NetIPAddress -IPAddress $ipAddress -PrefixLength 24 # -DefaultGateway "192.168.1.1"

# Set DNS servers.
$networkInterface | Set-DnsClientServerAddress -ServerAddresses $dnsServers

# Set DNS search suffix.
$networkInterface | Set-DnsClient -ConnectionSpecificSuffix $dnsSuffix

# Append the new DNS suffix.
Set-DnsClientGlobalSetting -SuffixSearchList @("$dnsSuffix")

# Disable IPv6.
$networkInterface | Disable-NetAdapterBinding -ComponentID ms_tcpip6

# Rename NIC to HostOnly communications.
$networkInterface | Rename-NetAdapter -NewName "HostOnly"
