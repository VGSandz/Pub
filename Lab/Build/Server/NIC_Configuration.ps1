#Single NIC only.
$VMNIC =  Get-NetAdapter

# Network Interface Name (replace with the actual interface name).
$interfaceName = $VMNIC.Name

# Static IP configuration.
$ipAddress = "192.168.1.10"

$subnetMask = "255.255.255.0"
$dnsServers = "192.168.1.10"
$nicGateway = "192.168.1.1"
$dnsSuffix = "labone.local"
$nicPrefixLn = '24'

# Get the network interface.
$networkInterface = Get-NetAdapter | Where-Object { $_.Name -eq $interfaceName }

# Set the interface to use a static IP configuration.
$networkInterface | Set-NetIPInterface -Dhcp Disabled

# Set the IP address and subnet mask.
$networkInterface | New-NetIPAddress -IPAddress $ipAddress -PrefixLength $nicPrefixLn -DefaultGateway $nicGateway

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
