#Join the Server to Domain. [Domain Controller Promotion]
#This command is as simple as it gets because the server would be promoted to a Domain Controller. 
#There is no necessary to keep the server into a specific OU.
#DNS lookup of the domain has to work for this command to execute properly.

$domain_name = "labone.local"
Add-Computer -DomainName $domain_name -Credential (Get-Credential) -Restart

#Join the Server to Domain. [Workstations,Servers, etc]
#Get the Domain.
$domain_name = "labone.local" ## Custom Domain
#get the OU information.
$ou = "OU=Servers,OU=Resources,DC=labone,DC=local" # Update OU as required, this attribute is the DN of the OU in Attributes.
#Join the server to the Domain and place it in the respective OU.
#This would prompt for Credentials which should be of your domain to which the server is about to be joined.
Add-Computer -DomainName $domain_name -OUPath $ou -Credential (Get-Credential) -Restart
