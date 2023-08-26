#Rename computer
rename-computer console01 -Restart

#install Windows Features of ADDS and DNS.
Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools -Verbose -restart



#DSRM Password for LAB, change it accordingly. 
$DSRMPassword = "P@ssw0rd1!" | ConvertTo-SecureString -AsPlainText -Force

#Install AD DS role for new Forest and new domain
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

#The computer will automatically restart after the above command.
