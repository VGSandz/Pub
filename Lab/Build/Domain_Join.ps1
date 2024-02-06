#Join the Server to Domain.
#This command is as simple as it gets because the server would be promoted to a Domain Controller. 
#There is no necessary to keep the server into a specific OU.
#DNS lookup of the domain has to work for this command to execute properly.

$domain_name = "labone.local"
Add-Computer -DomainName $domain_name -Credential (Get-Credential) -Restart
