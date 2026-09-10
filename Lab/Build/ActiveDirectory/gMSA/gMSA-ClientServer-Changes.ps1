# Step 1 - Install RSAT AD tools if not already present
# (needed for Install-ADServiceAccount)
Install-WindowsFeature RSAT-AD-PowerShell

# Step 2 - Install the gMSA on this server
# This tells the local machine to cache and manage the account
Install-ADServiceAccount -Identity "<insert the gMSA account>"

# Step 3 - Verify the server can retrieve the managed password
Test-ADServiceAccount -Identity "<insert the gMSA account>"
# Must return True. If it returns False, check group membership
# and that the Kerberos ticket has been refreshed (reboot or klist purge)

# Step 4 - Configure service with gMSA account.
1. Ensure you provide the user account as follows.
<DOMAIN>\<gMSA account>$ # example LABDOM\gmsa-iis$
