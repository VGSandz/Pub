#Set the DNS server to Listen only on the NIC IP
# Replace the IP for which the DNS accepts the incoming. This will also disable listening on all IPs.
# update accordingly before calling the command.
dnscmd /ResetListenAddresses 192.168.1.10

#Create a reverse lookup zone.
# Network is 192.169.1.0
# -DynamicUpdate Secure , Allows only Secure Updates.
# -ReplicationScope Forest , Replication is applicable to All Domain Controllers in the Forest.
# update accordingly before calling the command.
Add-DnsServerPrimaryZone -DynamicUpdate Secure -Name 168.192.in-addr.arpa -ReplicationScope Forest

#Restart the DNS service after the change.
Restart-Service DNS -Verbose

