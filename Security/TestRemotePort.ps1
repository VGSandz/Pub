$RemoteServerIPAddress =”y.y.y.y”
$LocalPorttoUse = "xxxx"
$RemotePorttoCheck = "yyyy"

#Normalize the Local IP Addresses to use any IP.
$LocalIPAddress  = [IPAddress]::Any

#Normalize the Remote IP Addresses.
$RemoteIPAddress  = [System.Net.IPAddress]::Parse($RemoteServerIPAddress)

#Local endpoint and remote endpoint
$LocalEndPointAddress  = New-Object Net.IPEndPoint ($LocalIPAddress,$LocalPorttoUse)
$RemoteEndPointAddress  = New-Object Net.IPEndPoint ($RemoteIPAddress,$RemotePorttoCheck)

$OpenTCPClient = New-Object Net.Sockets.TcpClient($LocalEndPointAddress)

Write-Output “Conecting to $RemoteServerIPAddress ..."
try 
{
    $OpenTCPClient.connect($RemoteEndPointAddress)
    Write-Output “Connected to Remote Server $RemoteServerIPAddress on Port $RemotePorttoCheck.”
    #even if we close the connection with the below call, the local port will stay occupied probably in finwait state.
    #this would cause errors if the script is called in short intervals.
    #there should be a check to validate if the port is absolutely free.
    $OpenTCPClient.close()
    
    
}
catch
{
  Write-Output “Error while establishing the connection to the remote system.”
  $OpenTCPClient.close()
}
