# Install the Windows Failover Cluster role.
# Restart Warning !! The role installation requires a reboot. 
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools -Restart

# Verify/Validate the role is installed.
Get-WindowsFeature -Name Failover-Clustering

# Validate nodes before cluster build. This is mandatory step that provides information about the compatibility and possible issues.
# Read the report generated at the end of this command to verify any reported issues

$nodes = "Node1", "Node2"  # Replace with the names of your servers
Test-Cluster -Node $nodes 

# The account used to run the below commands either have to be accounts that can create / update / modify domain objects.
# Ideally running with Domain Admins account will take care of all the pre-requesites on AD objects. But not recommended.

$nodes = "Node1", "Node2"  # Replace with the names of your servers
$clusterName = "clustersrv" # Replace with your desired cluster name
$ipAddress = "192.168.1.100" # Replace with your cluster IP address

New-Cluster -Name $clusterName -Node $nodes -StaticAddress $ipAddress  -NoStorage 

# Add available cluster disks.
Get-ClusterAvailableDisk | Add-ClusterDisk

# Configure Quorum Disk.
---
