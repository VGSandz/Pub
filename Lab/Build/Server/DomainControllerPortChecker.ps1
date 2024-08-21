<#

  This script can be used to check if the necessary ports are open from a client machine to Domain Controller to successfully domain join.

    TCP/UDP 53 - DNS

    TCP/UDP 88 - Kerberos authentication

    UDP 123 - NTP

    TCP 135 - RPC

    UDP 137-138 - Netlogon

    TCP 139 - Netlogon

    TCP/UDP 389 - LDAP; note that AWS Directory Service does not support LDAP with SSL (LDAPS) or LDAP signing

    TCP/UDP 636 - LDAP over SSL

    TCP/UDP 445 - SMB

    TCP 873 - FRS

    TCP 3268 - Global Catalog

    TCP/UDP 1024-65535 - Ephemeral ports for RPC

#>

Write-Output "Basic Domain-Join check."

#3268 may not be a mandatory port required to be open, unless the Server is about to be a domain controller.

$Ports1 = "53
88
135
139
389
445
636
3268" -split("`n")  

#$domainDC = "IP Address of DC"
$domainDC = "xx.xx.xx.xx"

foreach ($PortA in $Ports1)
{
Test-NetConnection -ComputerName $domainDC -Port $PortA | select RemotePort,TcpTestSucceeded
}

