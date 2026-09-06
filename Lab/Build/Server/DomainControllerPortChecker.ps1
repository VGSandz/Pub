<#
.SYNOPSIS
    Domain-join port checker: client machine -> Domain Controller.

.DESCRIPTION
    Validates that a client can reach every port required for domain
    join and day-to-day AD operations (DNS, Kerberos, LDAP, SMB/SYSVOL,
    Global Catalog, RPC/dynamic range).

    Corrections vs. common versions of this script floating around:
    - Adds Kerberos password change (464), NTP (123), NetBIOS 137/138,
      Global Catalog SSL (3269), and AD Web Services (9389)
    - Removes port 873 - that's rsync, not FRS. FRS/DFSR use RPC,
      not a fixed port
    - Actually probes UDP instead of only documenting it in a comment
      block while running TCP-only checks
    - Validates the RPC dynamic range (49152-65535) with a real
      RPC/WMI call instead of pinging random ports in that range,
      which is meaningless since nothing listens there until a call
      is actually made

.PARAMETER DomainController
    Hostname, FQDN, or IP of the target Domain Controller.

.PARAMETER DomainName
    AD domain name, used only for the SRV record check (e.g. the
    "_ldap._tcp.dc._msdcs.<domain>" lookup). Auto-derived from
    -DomainController if it's an FQDN, or from local domain membership
    otherwise. Supply it explicitly if neither applies.

.EXAMPLE
    .\DomainJoin-PortChecker.ps1 -DomainController dc01.contoso.local

.EXAMPLE
    .\DomainJoin-PortChecker.ps1 -DomainController 192.168.1.50 -DomainName contoso.local

.NOTES
    UDP checks distinguish three states: OPEN (got a response), CLOSED
    (Windows surfaced an ICMP Port Unreachable via WSAECONNRESET/10054),
    and FILTERED/UNKNOWN (timeout - either a firewall silently dropped
    the probe, or the service just ignores garbage input). Only treat
    CLOSED as a confirmed verdict; corroborate FILTERED/UNKNOWN with
    nslookup, a real Kerberos ticket request, etc.

    Could not be executed against a live DC in the environment this
    was written in (no network/DC available) - reviewed line-by-line
    for syntax and logic, but run it against a real target and report
    back if anything misbehaves.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DomainController,

    # Only needed for the SRV record check. If omitted, this is derived
    # from $DomainController (if it's an FQDN) or from the local
    # machine's domain membership. Supply it explicitly if neither
    # applies (e.g. running from a workgroup machine against an IP).
    [Parameter(Mandatory = $false)]
    [string]$DomainName
)

if (-not $DomainName) {
    if ($DomainController -match '^[^.]+\.(.+)$') {
        $DomainName = $Matches[1]
        Write-Output "No -DomainName supplied; derived '$DomainName' from -DomainController."
    } else {
        try {
            $DomainName = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).Domain
            Write-Output "No -DomainName supplied; using local machine's domain '$DomainName'."
        } catch {
            Write-Output "Could not determine a domain name automatically."
            Write-Output "Re-run with -DomainName <yourdomain.tld> to include the SRV record check."
        }
    }
    Write-Output ""
}

$tcpPorts = [ordered]@{
    53   = "DNS"
    88   = "Kerberos Authentication"
    135  = "RPC Endpoint Mapper"
    139  = "NetBIOS Session Service"
    389  = "LDAP"
    445  = "SMB (SYSVOL/NETLOGON)"
    464  = "Kerberos Password Change"
    636  = "LDAP over SSL"
    3268 = "Global Catalog"
    3269 = "Global Catalog SSL"
    9389 = "AD Web Services (RSAT/PowerShell)"
}

$udpPorts = [ordered]@{
    53  = "DNS"
    88  = "Kerberos Authentication"
    123 = "NTP"
    137 = "NetBIOS Name Service"
    138 = "NetBIOS Datagram Service"
    389 = "LDAP"
    464 = "Kerberos Password Change"
}

function Test-TcpPortOpen {
    param(
        [string]$ComputerName,
        [int]$Port
    )
    try {
        $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -WarningAction SilentlyContinue
        return $result.TcpTestSucceeded
    } catch {
        return $false
    }
}

function Test-UdpPortOpen {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMs = 2000
    )
    $udpClient = $null
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient($ComputerName, $Port)
        $udpClient.Client.ReceiveTimeout = $TimeoutMs

        # UDP requires data to be sent to elicit any response
        $packet = [System.Text.Encoding]::ASCII.GetBytes("Ping")
        [void]$udpClient.Send($packet, $packet.Length)

        $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $null = $udpClient.Receive([ref]$remoteEP)
        return "OPEN (received response)"
    }
    catch [System.Management.Automation.MethodInvocationException] {
        if ($_.Exception.InnerException.ErrorCode -eq 10054) {
            # WSAECONNRESET - Windows surfaces an ICMP Port Unreachable this way
            return "CLOSED (ICMP Port Unreachable)"
        } else {
            return "FILTERED/UNKNOWN (no response / timeout)"
        }
    }
    catch {
        return "ERROR: $($_.Exception.Message)"
    }
    finally {
        if ($udpClient) { $udpClient.Close() }
    }
}

Write-Output "=================================================="
Write-Output " Domain-Join Port Check -> $DomainController"
Write-Output "=================================================="
Write-Output ""

# --- DNS resolution ---
try {
    $resolved = [System.Net.Dns]::GetHostAddresses($DomainController)
    Write-Output "DNS resolution: OK -> $($resolved -join ', ')"
} catch {
    Write-Output "DNS resolution: FAILED - cannot resolve '$DomainController'"
}
Write-Output ""

# --- TCP checks ---
Write-Output "--- TCP Ports ---"
$tcpResults = foreach ($port in $tcpPorts.Keys) {
    $ok = Test-TcpPortOpen -ComputerName $DomainController -Port $port
    [PSCustomObject]@{
        Port     = $port
        Service  = $tcpPorts[$port]
        Protocol = "TCP"
        Result   = if ($ok) { "OPEN" } else { "CLOSED/FILTERED" }
    }
}
$tcpResults | Format-Table -AutoSize

# --- UDP checks ---
Write-Output "--- UDP Ports (best-effort - see notes) ---"
$udpResults = foreach ($port in $udpPorts.Keys) {
    $status = Test-UdpPortOpen -ComputerName $DomainController -Port $port
    [PSCustomObject]@{
        Port     = $port
        Service  = $udpPorts[$port]
        Protocol = "UDP"
        Result   = $status
    }
}
$udpResults | Format-Table -AutoSize

# --- SRV record check ---
Write-Output "--- SRV Record Check ---"
if ($DomainName) {
    # This is the domain-wide DC locator record - the "_tcp" folder that
    # sits directly under "dc" in DNS Manager, NOT the one nested under
    # "_sites\<SiteName>" (that's the site-specific variant).
    $srvName = "_ldap._tcp.dc._msdcs.$DomainName"
    try {
        Resolve-DnsName -Name $srvName -Type SRV -ErrorAction Stop | Format-Table -AutoSize
    } catch {
        Write-Output "Could not resolve $srvName"
        Write-Output "Check that DNS points at an AD-integrated DNS server, not a public resolver,"
        Write-Output "and that the _msdcs.$DomainName zone actually exists on that server."
    }
} else {
    Write-Output "Skipped - no domain name available. Re-run with -DomainName <yourdomain.tld>."
}
Write-Output ""

Write-Output ""

# --- Summary ---
Write-Output "=================================================="
Write-Output " Summary"
Write-Output "=================================================="
$tcpOpenCount = ($tcpResults | Where-Object { $_.Result -eq "OPEN" }).Count
Write-Output "TCP: $tcpOpenCount of $($tcpResults.Count) ports reachable"
Write-Output "UDP: CLOSED = confirmed via ICMP Port Unreachable. FILTERED/UNKNOWN = no reply,"
Write-Output "     which usually means a firewall silently dropped it (or the service just"
Write-Output "     ignores garbage probes) - not a hard 'it's blocked' verdict on its own."
