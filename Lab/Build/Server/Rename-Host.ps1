# This command will rename the Computer and would Restart IMMEDIATELY! 
$newServerName = "Server01" # Change the Server name accordingly.
Rename-Computer $newServerName -Restart
