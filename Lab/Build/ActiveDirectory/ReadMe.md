# Active Directory Lab Build

Scripts and reference notes for building a single-forest Active Directory lab:
promote domain controllers, configure DNS, populate OUs / groups / users, and
set up group Managed Service Accounts (gMSA). Firewall port requirements for
domain join are included at the bottom.

> **Lab use only.** Passwords in these scripts (DSRM, default user password) are
> throwaway lab values. Change them, and never reuse them outside a lab.

## Contents

| Path | Purpose | Run on |
|---|---|---|
| [`ADDS_Roles.ps1`](ADDS_Roles.ps1) | Install AD DS + DNS; promote the first DC of a new forest **or** add an additional DC | New server |
| [`DNS_Configuration.ps1`](DNS_Configuration.ps1) | Restrict the DNS listen address; create an AD-integrated reverse lookup zone | DC |
| [`UserManagement/Populate_AD_Objects.ps1`](UserManagement/Populate_AD_Objects.ps1) | Build the OU tree, Tier 0/1/2 + delegation + department groups, and demo users | DC |
| [`UserManagement/ReadMe.md`](UserManagement/ReadMe.md) | One-liner cheat sheet: users, groups, OUs, gMSA, health and replication checks | DC |
| [`gMSA/gMSA-DomainController-Changes.ps1`](gMSA/gMSA-DomainController-Changes.ps1) | KDS root key, gMSA host group, create the gMSA | DC |
| [`gMSA/gMSA-ClientServer-Changes.ps1`](gMSA/gMSA-ClientServer-Changes.ps1) | Install and test the gMSA, then assign it to a service | Member server |

## Prerequisites

- Windows Server 2016 or later (the scripts use the `WinThreshold` functional level)
- Elevated PowerShell session
- Static IP and final hostname set **before** promotion
- Domain / Enterprise Admin rights for the DC, gMSA, and populator scripts
- Hostnames, domain name, and IPs in each script are examples. Edit them first.

## Build order

1. **Promote the DC: `ADDS_Roles.ps1`**
   Two independent blocks. Run one:
   - *New forest:* installs `AD-Domain-Services` + `DNS`, runs `Install-ADDSForest`, reboots automatically.
   - *Additional DC:* same role install, then `Install-ADDSDomainController` (prompts for domain admin credentials).

   Before running, edit the domain name, NetBIOS name, and `$DSRMPassword`.

2. **Configure DNS: `DNS_Configuration.ps1`**
   Set the listen address to the DC's own IP, create the reverse zone (secure dynamic updates only, forest-wide replication), restart the DNS service. Edit the IP and network first.

3. **Populate the lab: `UserManagement/Populate_AD_Objects.ps1`**

   ```powershell
   .\Populate_AD_Objects.ps1 -WhatIf                        # preview
   .\Populate_AD_Objects.ps1                                # 30 users, 7 departments
   .\Populate_AD_Objects.ps1 -UserCount 50 -ProtectOUs:$false   # bigger, easy teardown
   ```

   Safe to re-run: existing OUs, groups, and users are skipped. Creates:

   ```
   DC=<yourdomain>
   |-- OU=Admin\Groups\Tier          SG-Tier0/1/2-Admins
   |-- OU=Admin\Groups\Delegation    DEL-* delegation groups
   |-- OU=Admin\Groups\Departments   SG-<Dept>-All
   |-- OU=Departments\<Dept>         users
   |-- OU=ServiceAccounts
   `-- OU=Staging                    disabled / offboarded users
   ```

   Groups and users live in separate branches on purpose, which keeps OU-level delegation clean.

4. **gMSA**
   1. On a DC: `gMSA/gMSA-DomainController-Changes.ps1` (KDS root key, host group, gMSA).
   2. On the member server: `gMSA/gMSA-ClientServer-Changes.ps1` (install, test, assign to service).

For day-to-day administration afterwards, use the cheat sheet in
[`UserManagement/ReadMe.md`](UserManagement/ReadMe.md).

---

## Firewall port requirements: client and domain controller

### Quick reference: minimum for a domain join

| Service | Port | Protocol |
|---|---|---|
| DNS (DC locator SRV lookups) | 53 | TCP/UDP |
| Kerberos | 88 | TCP/UDP |
| Time sync | 123 | UDP |
| RPC endpoint mapper | 135 | TCP |
| LDAP / CLDAP (DC locator) | 389 | TCP/UDP |
| SMB | 445 | TCP |
| Kerberos password change | 464 | TCP/UDP |
| RPC dynamic range | 49152-65535 | TCP |

If a join fails, check DNS first: the client must resolve the domain's SRV records.

### Section 1: client to domain controller

Standard AD authentication, LDAP, and GPO/SYSVOL. The client initiates and the DC
responds. A stateful firewall (including Windows Firewall) handles return traffic
automatically, so no separate inbound rule is needed on the client.

| Service | Port | Protocol | Notes |
|---|---|---|---|
| DNS | 53 | TCP/UDP | |
| Kerberos authentication | 88 | TCP/UDP | |
| NTP (time sync) | 123 | UDP | |
| RPC endpoint mapper | 135 | TCP | |
| NetBIOS name service | 137 | UDP | Legacy / optional |
| NetBIOS datagram service | 138 | UDP | Legacy / optional |
| NetBIOS session service | 139 | TCP | Legacy / optional |
| LDAP / CLDAP | 389 | TCP/UDP | |
| LDAP over SSL (LDAPS) | 636 | TCP | Only if LDAPS is enforced |
| SMB (SYSVOL / NETLOGON shares) | 445 | TCP | |
| Kerberos password change | 464 | TCP/UDP | |
| Global Catalog LDAP | 3268 | TCP | Required in multi-domain forests; also used for UPN and universal-group lookups, so allow it |
| Global Catalog LDAP over SSL | 3269 | TCP | Only if LDAPS is enforced |
| AD Web Services | 9389 | TCP | RSAT / AD PowerShell module |
| RPC dynamic port range | 49152-65535 | TCP | GPO processing, WMI, misc RPC |

**Hardening notes**

- Ports 137-139 (NetBIOS) can usually be dropped entirely in a modern, all-Windows, DNS-only environment.
- The RPC dynamic range can be narrowed via registry (`HKLM\SOFTWARE\Microsoft\Rpc\Internet`) or GPO if you want a tighter band.
- 636 / 3269 only matter if a certificate is deployed on the DC and you actually enforce signed / encrypted LDAP.

### Section 2: domain controller / admin workstation to client

Remote management only. This is **not** part of normal AD auth or GPO flow.
The DC or admin box initiates and the client responds. These ports are **off by
default** in the client's Windows Firewall and must be pushed via GPO. Microsoft
ships a Starter GPO, "Group Policy Remote Update Firewall Ports", that covers the
Remote GPUpdate rows.

| Scenario | Port | Protocol |
|---|---|---|
| Remote GPUpdate: RPC endpoint mapper | 135 | TCP |
| Remote GPUpdate: Task Scheduler (RPC) | 49152-65535 | TCP |
| Remote GPUpdate: WMI call | 49152-65535 (MS docs list "all ports") | TCP |
| PsExec / SC.exe: Admin$ share | 445 | TCP |
| PsExec / SC.exe: Service Control Manager (RPC) | 135 + 49152-65535 | TCP |
| Remote Registry / Remote Event Viewer | 445 + 135 + 49152-65535 | TCP |
| WinRM / PowerShell Remoting (HTTP) | 5985 | TCP |
| WinRM / PowerShell Remoting (HTTPS) | 5986 | TCP |
| RDP to the client | 3389 | TCP |
| ICMP echo (ping troubleshooting) | n/a | ICMP |

Predefined Windows Firewall rule groups to enable via GPO:

- Remote Scheduled Tasks Management (RPC)
- Remote Scheduled Tasks Management (RPC-EPMAP)
- Windows Management Instrumentation (WMI-In)

**Notes**

- Section 1 covers everyday AD operations: logon, Kerberos auth, LDAP queries, GPO/SYSVOL retrieval, password changes.
- Section 2 only applies when you actively manage clients **from** the DC or an admin box. Do not open these across the whole client VLAN. Restrict them to your management subnet / jump box.
- DC-to-DC replication needs additional rules beyond this client-facing list.

### Verify connectivity from a client

```powershell
$Domain = "contoso.com"           # your domain
$DC     = "dc01.contoso.com"      # a domain controller FQDN

# 1. Can the client find a DC through DNS?
Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.$Domain"

# 2. TCP ports (636 / 3269 show closed if LDAPS isn't configured. That's expected.)
53, 88, 135, 389, 445, 464, 636, 3268, 3269, 9389 | ForEach-Object {
    [pscustomobject]@{
        Port = $_
        Open = (Test-NetConnection -ComputerName $DC -Port $_ -WarningAction SilentlyContinue).TcpTestSucceeded
    }
} | Format-Table -AutoSize

# 3. DC locator (exercises the UDP 389 / CLDAP path that Test-NetConnection can't test)
nltest /dsgetdc:$Domain
```

*Port reference originally generated for WindowsTech (@ItsWindowsTech).*

---

## Best practices

### Deployment
- **Run at least two DCs per domain.** Add the second with the "additional DC" block in `ADDS_Roles.ps1`.
- **Avoid `.local` for real domains.** It collides with mDNS. Use a subdomain of a name you own (e.g. `ad.contoso.com`).
- **Point DCs at each other for DNS**, with `127.0.0.1` as the secondary. Never point domain-joined machines at public DNS.
- **Pick the highest functional level** all your DCs support. `WinThreshold` is the 2016 level.
- **Enable the AD Recycle Bin** (irreversible, so decide deliberately):
  `Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADForest).RootDomain`
- **Time:** the PDC emulator should sync from a reliable external NTP source. Everything else follows the domain hierarchy. Kerberos breaks beyond a 5-minute skew.
- **Back up system state** on at least one DC per domain and test restores. Don't restore DC VM snapshots.
- **Production:** keep NTDS/SYSVOL on a data volume, separate from the OS disk.

### DNS
- **Match the reverse zone to the subnet.** For `192.168.1.0/24`, use `Add-DnsServerPrimaryZone -NetworkId "192.168.1.0/24" -ReplicationScope Forest -DynamicUpdate Secure`. A zone named `168.192.in-addr.arpa` covers the whole /16.
- **Prefer `Set-DnsServerSetting -ListenAddresses <ip>`** over the legacy `dnscmd`. Make sure the addresses you list include every IP clients use to reach the server.
- **Secure dynamic updates only** on AD-integrated zones.
- **Configure scavenging deliberately** (no-refresh / refresh intervals) to avoid stale records.
- **Use forwarders** to trusted resolvers rather than relying on root hints.

### Secrets and scripts
- **Don't hardcode passwords in scripts, especially in a public repo.** Prompt instead: `Read-Host -AsSecureString`, `Get-Credential`, or a vault (`Microsoft.PowerShell.SecretManagement`).
- **`ConvertTo-SecureString -AsPlainText -Force` leaves the plaintext in the script and in PowerShell history / logs.** Fine for a lab, not beyond it.
- **Use `-WhatIf`** on every write cmdlet the first time you run something.
- **Keep domain-specific values in variables** (`Get-ADDomain` gives you DN, FQDN, and NetBIOS name) so scripts move between labs unchanged.
- **Store the DSRM password securely.** Reset it when needed with `ntdsutil "set dsrm password"`.

### Tiering and delegation
- **Follow the Microsoft Enterprise Access Model.** Tier 0 (identity plane), Tier 1 (servers), Tier 2 (workstations).
- **Keep Domain / Enterprise / Schema Admins empty** except when a task needs them. Delegate through OU-scoped groups (the `DEL-*` groups) instead.
- **This lab models tiers as groups only.** In production, give each admin a dedicated account per tier and never use those accounts for email or browsing.
- **Add privileged accounts to Protected Users.** Not service accounts or computer accounts.
- **Administer from a jump host / PAW**, not interactive logons to DCs from workstations.
- **Deploy Windows LAPS** for local administrator passwords on servers and workstations.
- **Require LDAP signing** (and consider channel binding), and disable SMBv1.
- **Rotate the `krbtgt` password** on a schedule, twice with replication in between.
- **Offboarding flow:** disable, move to `Staging`, retain, then delete. The AD Recycle Bin is the safety net.
- **Keep OU protection on** (`-ProtectOUs $true`, the default). Turn it off only while iterating on a lab.

### gMSA
- **KDS root key: match the method to the environment.**
  - *Single-DC lab:* backdate it: `Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)`. Confirm event 4004 in the KDS log.
  - *Multi-DC / production:* `Add-KdsRootKey -EffectiveImmediately`, then wait up to 10 hours for replication before creating gMSAs.
  - Check first with `Get-KdsRootKey`. It is one per forest. If you recreate it, restart the KDC service on all DCs.
- **Use one security group per gMSA / app tier**, and add **computer accounts** (with the trailing `$`).
- **After adding a server to the group, reboot it** or run `klist -li 0x3e7 purge` so it picks up a new ticket with the updated membership.
- **Don't hardcode the domain** in `-DNSHostName`. Build it from `(Get-ADDomain).DNSRoot`.
- **Set `-KerberosEncryptionType AES128,AES256`** and, for Kerberos-authenticated services, `-ServicePrincipalNames`.
- **Pass `-Path` on `New-ADServiceAccount`** to place gMSAs in a dedicated OU (e.g. `ServiceAccounts`) instead of the default Managed Service Accounts container.
- **Configure the service as `DOMAIN\gmsa-name$` with a blank password.** Passwords rotate automatically (30 days by default).

### Firewall
- **Don't disable Windows Firewall on DCs.** Manage rules through GPO.
- **Drop NetBIOS (137-139)** unless a legacy dependency requires it.
- **Scope Section 2 (management) ports to the admin subnet or jump host**, never the whole client network.
- **Narrow the RPC dynamic range** if you need a tighter firewall band.

### Operations
- **Health check regularly:** `dcdiag`, `repadmin /replsummary`, `repadmin /showrepl`, and `Get-ADReplicationFailure` (see the cheat sheet).
- **Verify the SYSVOL replication mechanism** (`dfsrmig /getglobalstate`) so you're on DFSR, not FRS.
- **Keep the forest tidy:** review stale accounts and empty groups on a schedule.

---

## References

- [Service overview and network port requirements for Windows](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/service-overview-and-network-port-requirements)
- "Configure Firewall Port Requirements for Group Policy" (Microsoft)
- [Create the KDS root key](https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/create-the-key-distribution-services-kds-root-key)
- [Group Managed Service Accounts overview](https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)
- [Enterprise access model](https://learn.microsoft.com/security/privileged-access-workstations/privileged-access-access-model)
- [Best practices for securing Active Directory](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory)
- [Windows LAPS overview](https://learn.microsoft.com/windows-server/identity/laps/laps-overview)
