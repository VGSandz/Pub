#############################################################################################################################
# Fresh deployment of Single Forest/Domain, labone.local
#############################################################################################################################

# Install Windows Features of ADDS and DNS.
Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools -Verbose 


# DSRM Password for LAB, change it accordingly. 
$DSRMPassword = "P@ssw0rd1!" | ConvertTo-SecureString -AsPlainText -Force

# Install AD DS role for new Forest and new domain
Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "labone.local" `
-DomainNetbiosName "LABONE" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-SafeModeAdministratorPassword $DSRMPassword `
-Force:$true `
-Verbose

# The computer will automatically restart after the above command.

#############################################################################################################################
# Joining to an existing Domain, labone.local
#############################################################################################################################

# Install Windows Features of ADDS and DNS.
Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools -Verbose 


#DSRM Password for LAB, change it accordingly. 
$DSRMPassword = "P@ssw0rd1!" | ConvertTo-SecureString -AsPlainText -Force

# Windows PowerShell script for AD DS Deployment

Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$false `
-Credential (Get-Credential) `
-CriticalReplicationOnly:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainName "labone.local" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SiteName "Default-First-Site-Name" `
-SafeModeAdministratorPassword $DSRMPassword `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

# Provide Credentials of the labone.local Domain Administrator, when prompted.
# The computer will automatically restart after the above command.

