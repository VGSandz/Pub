#Script to enable inbound and outbound firewall rules on Lab Server.
# Any Protocol, Any Port, Any Direction, Allow.

# Define the properties for the new firewall rule
$RuleName = "Any_Any_Any"
$Enabled = "True"
$Direction = "Inbound"
$Action = "Allow"
$Profile = @("Public", "Private", "Domain")
$LocalPort = "Any"
$Protocol = "Any"

# Create the new firewall rule
New-NetFirewallRule -DisplayName $RuleName -Enabled $Enabled -Direction $Direction -Action $Action -Profile $Profile -LocalPort $LocalPort -Protocol $Protocol


# Define the properties for the new outbound firewall rule
$RuleName = "Any_Any_Any"
$Enabled = "True"
$Direction = "Outbound"
$Action = "Allow"
$Profile = @("Public", "Private", "Domain")
$LocalPort = "Any"
$Protocol = "Any"

# Create the new outbound firewall rule
New-NetFirewallRule -DisplayName $RuleName -Enabled $Enabled -Direction $Direction -Action $Action -Profile $Profile -LocalPort $LocalPort -Protocol $Protocol
