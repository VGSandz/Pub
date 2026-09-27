# AD PowerShell One-Liners

Companion cheat sheet for the video series. Assumes the OU tree created by
`New-LabADPopulator.ps1`:

```
DC=<yourdomain>
|-- OU=Admin\Groups\Tier          (SG-Tier0/1/2-Admins)
|-- OU=Admin\Groups\Delegation    (DEL-* groups)
|-- OU=Admin\Groups\Departments   (SG-<Dept>-All groups)
|-- OU=Departments\<Dept>         (users)
|-- OU=ServiceAccounts
`-- OU=Staging
```

## Setup (run once per session)

```powershell
$DomainDN   = (Get-ADDomain).DistinguishedName   # e.g. DC=contoso,DC=com
$DomainFQDN = (Get-ADDomain).DNSRoot             # e.g. contoso.com
$NetBIOS    = (Get-ADDomain).NetBIOSName         # e.g. CONTOSO
```

Every example below uses these three variables instead of a hardcoded domain
name, so the same sheet runs unchanged on labdomain.info or any other lab.

> Every `New-`, `Set-`, `Remove-`, `Move-`, `Add-`, `Disable-AD*` cmdlet below
> supports `-WhatIf`. Append it while you're testing a line on camera.

---

## Users

```powershell
# Create user
New-ADUser -Name "Jane Doe" -GivenName Jane -Surname Doe -SamAccountName jdoe `
    -UserPrincipalName "jdoe@$DomainFQDN" `
    -Path "OU=IT,OU=Departments,$DomainDN" `
    -AccountPassword (ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force) `
    -Enabled $true -ChangePasswordAtLogon $true

# Disable / enable
Disable-ADAccount -Identity jdoe
Enable-ADAccount -Identity jdoe

# Modify attributes (title, department, manager)
Set-ADUser -Identity jdoe -Title "Senior Engineer" -Department "Engineering" -Manager "asharma"

# Set an account expiration date
Set-ADAccountExpiration -Identity jdoe -DateTime (Get-Date).AddMonths(6)

# Reset password + force change at next logon
Set-ADAccountPassword -Identity jdoe -Reset `
    -NewPassword (ConvertTo-SecureString "NewP@ss2026!" -AsPlainText -Force)
Set-ADUser -Identity jdoe -ChangePasswordAtLogon $true

# Unlock a locked-out account
Unlock-ADAccount -Identity jdoe

# Move to a different OU (e.g. department transfer)
Move-ADObject -Identity (Get-ADUser jdoe).DistinguishedName `
    -TargetPath "OU=HR,OU=Departments,$DomainDN"

# Add / remove group membership
Add-ADGroupMember -Identity "SG-IT-All" -Members jdoe
Remove-ADGroupMember -Identity "SG-IT-All" -Members jdoe -Confirm:$false

# See everything a user belongs to
Get-ADPrincipalGroupMembership -Identity jdoe | Select-Object Name

# Report users by department
Get-ADUser -Filter "Department -eq 'IT'" -Properties Department, Title |
    Select-Object Name, Title

# Find inactive users (no logon in 90 days)
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly |
    Select-Object Name, LastLogonDate

# Bulk import from CSV (columns: Name, SamAccountName, OU, Department)
Import-Csv .\users.csv | ForEach-Object {
    New-ADUser -Name $_.Name -SamAccountName $_.SamAccountName -Path $_.OU `
        -Department $_.Department -Enabled $true `
        -AccountPassword (ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force) `
        -ChangePasswordAtLogon $true
}

# Delete user
Remove-ADUser -Identity jdoe -Confirm:$false
```

## Groups

```powershell
# Create a security group
New-ADGroup -Name "SG-Finance-Managers" -GroupScope Global -GroupCategory Security `
    -Path "OU=Departments,OU=Groups,OU=Admin,$DomainDN"

# Create a distribution group instead
New-ADGroup -Name "DL-Finance-Announce" -GroupScope Universal -GroupCategory Distribution `
    -Path "OU=Departments,OU=Groups,OU=Admin,$DomainDN"

# Add / remove members
Add-ADGroupMember -Identity "SG-Finance-Managers" -Members jdoe
Remove-ADGroupMember -Identity "SG-Finance-Managers" -Members jdoe -Confirm:$false

# List members
Get-ADGroupMember -Identity "SG-Finance-Managers" | Select-Object Name, SamAccountName

# Export a membership report
Get-ADGroupMember -Identity "SG-Finance-Managers" | Select-Object Name, SamAccountName |
    Export-Csv .\finance-managers.csv -NoTypeInformation

# Find empty groups
Get-ADGroup -Filter * | Where-Object { -not (Get-ADGroupMember $_.DistinguishedName) }

# Convert group scope
Set-ADGroup -Identity "SG-Finance-Managers" -GroupScope Universal

# Nest a group inside another (e.g. dept group into a tier group)
Add-ADGroupMember -Identity "SG-Tier1-Admins" -Members "SG-Finance-Managers"
```

## OUs

```powershell
# Create an OU
New-ADOrganizationalUnit -Name "Contractors" -Path "OU=Departments,$DomainDN" `
    -ProtectedFromAccidentalDeletion $true

# List every OU in the domain
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName

# Move an object into an OU
Move-ADObject -Identity (Get-ADUser jdoe).DistinguishedName `
    -TargetPath "OU=Contractors,OU=Departments,$DomainDN"

# Delegate control (example: reset password + unlock, via dsacls)
dsacls "OU=IT,OU=Departments,$DomainDN" /I:S `
    /G "$NetBIOS\DEL-IT-UserAdmins:CA;Reset Password;user"

# Remove accidental-deletion protection before deleting
Set-ADOrganizationalUnit -Identity "OU=Contractors,OU=Departments,$DomainDN" `
    -ProtectedFromAccidentalDeletion $false
Remove-ADOrganizationalUnit -Identity "OU=Contractors,OU=Departments,$DomainDN" -Confirm:$false

# Report every object under an OU
Get-ADObject -SearchBase "OU=IT,OU=Departments,$DomainDN" -Filter * |
    Select-Object Name, ObjectClass
```

## GMSA

```powershell
# Create the KDS root key (lab only — backdate so it's usable immediately;
# in production, the default 10-hour propagation delay is intentional)
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))

# Create a GMSA
New-ADServiceAccount -Name "svc-WebApp" -DNSHostName "svc-webapp.$DomainFQDN" `
    -PrincipalsAllowedToRetrieveManagedPassword "SG-Tier1-Admins" `
    -Path "OU=ServiceAccounts,$DomainDN"

# List existing GMSAs and who can retrieve their password
Get-ADServiceAccount -Filter * -Properties PrincipalsAllowedToRetrieveManagedPassword |
    Select-Object Name, PrincipalsAllowedToRetrieveManagedPassword

# Grant another group retrieval rights on an existing GMSA
Set-ADServiceAccount -Identity "svc-WebApp" `
    -PrincipalsAllowedToRetrieveManagedPassword (Get-ADGroup "SG-Tier2-Admins")

# Install the GMSA on a member server (run on that server, not the DC)
Install-ADServiceAccount -Identity "svc-WebApp"

# Confirm it works
Test-ADServiceAccount -Identity "svc-WebApp"

# Remove a GMSA
Remove-ADServiceAccount -Identity "svc-WebApp" -Confirm:$false
```

## AD Health Checks

```powershell
# Full diagnostic
dcdiag /v

# FSMO role holders
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster

# SYSVOL/DFSR migration + replication state
dfsrmig /getglobalstate
Get-WmiObject -Namespace "root\microsoftdfs" -Class DfsrReplicatedFolderInfo

# DNS SRV record check
nslookup -type=srv "_ldap._tcp.dc._msdcs.$DomainFQDN"

# Time sync status
w32tm /query /status

# Tombstone lifetime
Get-ADObject "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$DomainDN" `
    -Property tombstoneLifetime

# AD Recycle Bin status (irreversible once enabled — good talking point on camera)
Get-ADOptionalFeature -Filter 'Name -eq "Recycle Bin Feature"' |
    Select-Object Name, EnabledScopes
```

## Replication Checks

```powershell
# Replication summary across all DCs
repadmin /replsummary

# Detailed per-partner status
repadmin /showrepl

# Force replication to all partners
repadmin /syncall /AdeP

# Replication metadata via PowerShell
Get-ADReplicationPartnerMetadata -Target (Get-ADDomainController).HostName -Scope Server

# Surface replication failures directly
Get-ADReplicationFailure -Target (Get-ADDomainController -Filter *).Name

# Check the outbound replication queue
repadmin /queue

# Review site links
Get-ADReplicationSiteLink -Filter *
```
