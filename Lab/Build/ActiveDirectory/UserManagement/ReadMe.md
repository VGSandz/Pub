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
## Setup (run once per session)

$DomainDN   = (Get-ADDomain).DistinguishedName   # e.g. DC=contoso,DC=com
$DomainFQDN = (Get-ADDomain).DNSRoot             # e.g. contoso.com
$PDC        = (Get-ADDomain).PDCEmulator         # lockouts are logged here


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
Set-ADUser -Identity jdoe `
    -Title "Senior Engineer" `
    -Department "Engineering" `
    -Manager "prao" `
    -EmailAddress "jane.doe@$DomainFQDN" `
    -EmployeeID "10023"

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

## 0. See everything about a user


# The 12 fields most helpful
Get-ADUser jdoe -Properties Enabled, LockedOut, LastLogonDate, PasswordLastSet, PasswordExpired, PasswordNeverExpires, AccountExpirationDate, Department, Title, Manager, EmailAddress, WhenCreated |
    Format-List Name, SamAccountName, Enabled, LockedOut, LastLogonDate, PasswordLastSet, PasswordExpired, PasswordNeverExpires, AccountExpirationDate, Department, Title, Manager, EmailAddress, WhenCreated

# Every attribute AD holds for the user
Get-ADUser jdoe -Properties * | Format-List *

# Just the attribute NAMES available to query (handy for "what can I ask for?")
(Get-ADUser jdoe -Properties *).PropertyNames | Sort-Object

# Find a user by name, email, UPN, or employee ID
Get-ADUser -Filter "Name -like 'Jane*'"
Get-ADUser -Filter "mail -eq 'jane.doe@$DomainFQDN'"
Get-ADUser -Filter "UserPrincipalName -eq 'jdoe@$DomainFQDN'"
Get-ADUser -Filter "EmployeeID -eq '10023'" -Properties EmployeeID


## 1. Account lockout

powershell
# Is this user locked out right now, and why might it be?
Get-ADUser jdoe -Properties LockedOut, AccountLockoutTime, BadLogonCount, LastBadPasswordAttempt |
    Select-Object Name, LockedOut, AccountLockoutTime, BadLogonCount, LastBadPasswordAttempt

# List every locked-out user in the domain
Search-ADAccount -LockedOut -UsersOnly | Select-Object Name, SamAccountName, LockedOut, LastLogonDate

# Locked-out users in one OU only
Search-ADAccount -LockedOut -UsersOnly -SearchBase "OU=IT,OU=Departments,$DomainDN" | Select-Object Name, SamAccountName

# Unlock one user / unlock everyone who is locked
Unlock-ADAccount -Identity jdoe
Search-ADAccount -LockedOut -UsersOnly | Unlock-ADAccount

# Check the lockout state on every DC (spots replication lag of the lockout itself)
Get-ADDomainController -Filter * | ForEach-Object { $dc = $_.HostName; Get-ADUser jdoe -Server $dc -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt | Select-Object @{n='DC';e={$dc}}, LockedOut, BadLogonCount, LastBadPasswordAttempt }

# WHO or WHAT is causing the lockout: event 4740 on the PDC emulator, last 24h
Get-WinEvent -ComputerName $PDC -FilterHashtable @{LogName='Security'; Id=4740; StartTime=(Get-Date).AddDays(-1)} |
    Select-Object TimeCreated, @{n='LockedUser';e={$_.Properties[0].Value}}, @{n='SourceComputer';e={$_.Properties[1].Value}}

# Same, for one user only
Get-WinEvent -ComputerName $PDC -FilterHashtable @{LogName='Security'; Id=4740} |
    Where-Object { $_.Properties[0].Value -eq 'jdoe' } |
    Select-Object TimeCreated, @{n='SourceComputer';e={$_.Properties[1].Value}}

# The lockout policy that decides all of this
Get-ADDefaultDomainPasswordPolicy | Select-Object LockoutThreshold, LockoutDuration, LockoutObservationWindow


> Needs the Security log readable on the PDC and Account Lockout auditing enabled.
> If 4740 shows a domain controller or a server as the source, look for stale
> credentials in services, scheduled tasks, mapped drives, or mobile mail apps.

## 2. Enabled / disabled

# One user
Get-ADUser jdoe | Select-Object Name, Enabled

# All disabled users
Get-ADUser -Filter 'Enabled -eq $false' | Select-Object Name, SamAccountName, DistinguishedName
Search-ADAccount -AccountDisabled -UsersOnly | Select-Object Name, SamAccountName

# Disabled users inside one OU, with last logon
Get-ADUser -Filter 'Enabled -eq $false' -SearchBase "OU=IT,OU=Departments,$DomainDN" -Properties LastLogonDate |
    Select-Object Name, LastLogonDate

# Count enabled vs disabled
Get-ADUser -Filter * | Group-Object Enabled | Select-Object Name, Count

# Disable / enable one user
Disable-ADAccount -Identity jdoe
Enable-ADAccount  -Identity jdoe

# Bulk disable leavers from a CSV (column: SamAccountName)
Import-Csv .\leavers.csv | ForEach-Object { Disable-ADAccount -Identity $_.SamAccountName }

# Full offboarding line: disable, stamp the date, move to Staging
Disable-ADAccount jdoe; Set-ADUser jdoe -Description "Disabled $(Get-Date -Format yyyy-MM-dd)"; Move-ADObject (Get-ADUser jdoe).DistinguishedName -TargetPath "OU=Staging,$DomainDN"

# Accounts that have expired, or expire in the next 14 days
Search-ADAccount -AccountExpired -UsersOnly | Select-Object Name, AccountExpirationDate
Search-ADAccount -AccountExpiring -TimeSpan 14.00:00:00 -UsersOnly | Select-Object Name, AccountExpirationDate

## 3. Last logon

# Quick answer (replicated value, can lag by ~2 weeks)
Get-ADUser vverma -Properties LastLogonDate | Select-Object Name, LastLogonDate

# Accurate answer: LastLogon is NOT replicated, so ask every DC and show each
Get-ADDomainController -Filter * | ForEach-Object { $dc = $_.HostName; $u = Get-ADUser vverma -Server $dc -Properties LastLogon; [pscustomobject]@{ DC = $dc; LastLogon = [datetime]::FromFileTime($u.LastLogon) } } | Sort-Object LastLogon -Descending

# Just the single most recent logon across all DCs
[datetime]::FromFileTime((Get-ADDomainController -Filter * | ForEach-Object { (Get-ADUser vverma -Server $_.HostName -Properties LastLogon).LastLogon } | Measure-Object -Maximum).Maximum)

# All users, newest logon first
Get-ADUser -Filter * -Properties LastLogonDate | Sort-Object LastLogonDate -Descending | Select-Object Name, LastLogonDate

# Stale: enabled users with no logon in 90 days
$cutoff = (Get-Date).AddDays(-90); Get-ADUser -Filter {Enabled -eq $true -and LastLogonDate -lt $cutoff} -Properties LastLogonDate | Select-Object Name, LastLogonDate | Sort-Object LastLogonDate

# Same idea, built-in cmdlet
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly | Where-Object Enabled | Select-Object Name, LastLogonDate

# Enabled users who have NEVER logged on
Get-ADUser -Filter 'Enabled -eq $true' -Properties LastLogonDate, WhenCreated | Where-Object { -not $_.LastLogonDate } | Select-Object Name, WhenCreated

# Export the stale report for the manager
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly | Select-Object Name, SamAccountName, LastLogonDate, DistinguishedName | Export-Csv .\stale-users.csv -NoTypeInformation

# How often does the replicated timestamp update? (blank = default of ~14 days)
(Get-ADDomain).LastLogonReplicationInterval


## 4. Password last set, expiry, and policy

# When was the password last changed?
Get-ADUser vverma -Properties PasswordLastSet | Select-Object Name, PasswordLastSet

# Password age in days
Get-ADUser vverma -Properties PasswordLastSet | Select-Object Name, @{n='AgeDays';e={((Get-Date) - $_.PasswordLastSet).Days}}

# When does it expire? (converts the computed attribute; use only for accounts that DO expire)
[datetime]::FromFileTime((Get-ADUser vverma -Properties 'msDS-UserPasswordExpiryTimeComputed').'msDS-UserPasswordExpiryTimeComputed')

# Expiry date for everyone who has one
Get-ADUser -Filter {Enabled -eq $true -and PasswordNeverExpires -eq $false} -Properties PasswordLastSet, 'msDS-UserPasswordExpiryTimeComputed' |
    Select-Object Name, PasswordLastSet, @{n='ExpiryDate';e={[datetime]::FromFileTime($_.'msDS-UserPasswordExpiryTimeComputed')}} | Sort-Object ExpiryDate

# Passwords expiring in the next 14 days (the helpdesk favourite)
Get-ADUser -Filter {Enabled -eq $true -and PasswordNeverExpires -eq $false} -Properties 'msDS-UserPasswordExpiryTimeComputed' |
    Select-Object Name, @{n='ExpiryDate';e={[datetime]::FromFileTime($_.'msDS-UserPasswordExpiryTimeComputed')}} |
    Where-Object { $_.ExpiryDate -gt (Get-Date) -and $_.ExpiryDate -lt (Get-Date).AddDays(14) } | Sort-Object ExpiryDate

# Already-expired passwords
Search-ADAccount -PasswordExpired -UsersOnly | Select-Object Name, SamAccountName

# Password never expires (flag / find / set)
Get-ADUser jdoe -Properties PasswordNeverExpires | Select-Object Name, PasswordNeverExpires
Search-ADAccount -PasswordNeverExpires -UsersOnly | Select-Object Name, SamAccountName
Set-ADUser jdoe -PasswordNeverExpires $true

# Users who must change password at next logon (PasswordLastSet is empty)
Get-ADUser -Filter 'Enabled -eq $true' -Properties PasswordLastSet | Where-Object { -not $_.PasswordLastSet } | Select-Object Name

# Accounts that don't require a password (audit finding)
Get-ADUser -Filter 'PasswordNotRequired -eq $true' | Select-Object Name, SamAccountName

# User can't change their own password?
Get-ADUser jdoe -Properties CannotChangePassword | Select-Object Name, CannotChangePassword

# The domain password policy (max age, length, complexity, history)
Get-ADDefaultDomainPasswordPolicy | Select-Object MaxPasswordAge, MinPasswordAge, MinPasswordLength, ComplexityEnabled, PasswordHistoryCount


> Gotcha: for accounts set to *password never expires*, the computed expiry value is
> a huge placeholder and `FromFileTime` will throw. Filter with
> `PasswordNeverExpires -eq $false` first, or use the report in section 6.

## 5. Update department, manager, and other attributes


# Common attributes have their own parameters
Set-ADUser jdoe -Department "Finance" -Title "Senior Analyst" -Manager prao -Office "Pune" -Company "Lab Corp" -Description "Finance team"

# Contact details
Set-ADUser jdoe -OfficePhone "+91-20-5550100" -MobilePhone "+91-98-5550100" -EmailAddress "jdoe@$DomainFQDN"

# HR fields
Set-ADUser jdoe -EmployeeID "10023" -EmployeeNumber "10023" -Division "Corporate" -DisplayName "Jane Doe"

# Address block
Set-ADUser jdoe -StreetAddress "1 Lab Street" -City "Pune" -State "MH" -PostalCode "411001" -Country "IN"

# Attributes with no dedicated parameter: use -Replace (LDAP attribute name)
Set-ADUser jdoe -Replace @{street = "Street 1"; physicalDeliveryOfficeName = "Building 4"}

# Add a value to a multi-valued attribute (e.g. a proxy address)
Set-ADUser jdoe -Add @{proxyAddresses = "smtp:jane.alias@$DomainFQDN"}

# Clear a value
Set-ADUser jdoe -Clear manager
Set-ADUser jdoe -Clear telephoneNumber, description

# Change UPN / logon name
Set-ADUser jdoe -UserPrincipalName "jane.doe@$DomainFQDN"
Set-ADUser jdoe -SamAccountName jane.doe

# Rename the object (CN) and keep name fields consistent
Get-ADUser jane.doe | Rename-ADObject -NewName "Jane Smith"; Set-ADUser jane.doe -Surname Smith -DisplayName "Jane Smith"

# Update every user in a department at once
Get-ADUser -Filter "Department -eq 'IT'" | Set-ADUser -Company "Lab Corp"

# Bulk update from CSV (columns: SamAccountName, Department, Title, Manager)
Import-Csv .\updates.csv | ForEach-Object { Set-ADUser -Identity $_.SamAccountName -Department $_.Department -Title $_.Title -Manager $_.Manager }

# Set one manager for a whole OU
Get-ADUser -Filter * -SearchBase "OU=HR,OU=Departments,$DomainDN" | Set-ADUser -Manager prao

# Verify the change
Get-ADUser jane.doe -Properties Department, Title, Manager, Office | Select-Object Name, Department, Title, Manager, Office


## 6. Reports people export

# One-table audit of every user (status, logon, password) to CSV
Get-ADUser -Filter * -Properties Enabled, LockedOut, LastLogonDate, PasswordLastSet, PasswordNeverExpires, 'msDS-UserPasswordExpiryTimeComputed', Department, Manager |
    Select-Object Name, SamAccountName, Enabled, LockedOut, LastLogonDate, PasswordLastSet, PasswordNeverExpires,
        @{n='PasswordExpiry';e={ if ($_.PasswordNeverExpires) {'Never'} else {[datetime]::FromFileTime($_.'msDS-UserPasswordExpiryTimeComputed')} }}, Department |
    Export-Csv .\user-audit.csv -NoTypeInformation

# Users created in the last 7 days
$since = (Get-Date).AddDays(-7); Get-ADUser -Filter {WhenCreated -ge $since} -Properties WhenCreated | Select-Object Name, WhenCreated

# Users changed in the last 24 hours
$since = (Get-Date).AddDays(-1); Get-ADUser -Filter {WhenChanged -ge $since} -Properties WhenChanged | Select-Object Name, WhenChanged

# Users with no manager / no email / no department
Get-ADUser -Filter * -Properties Manager | Where-Object { -not $_.Manager } | Select-Object Name
Get-ADUser -Filter * -Properties EmailAddress | Where-Object { -not $_.EmailAddress } | Select-Object Name
Get-ADUser -Filter * -Properties Department | Where-Object { -not $_.Department } | Select-Object Name

# A manager's name, and their direct reports
Get-ADUser jane.doe -Properties Manager | ForEach-Object { if ($_.Manager) { (Get-ADUser $_.Manager).Name } }
Get-ADUser prao -Properties DirectReports | Select-Object -ExpandProperty DirectReports

# Headcount per department
Get-ADUser -Filter * -Properties Department | Group-Object Department | Sort-Object Count -Descending | Select-Object Name, Count

# Members of a group, including nested groups
Get-ADGroupMember "SG-IT-All" -Recursive | Select-Object Name, SamAccountName

# Privileged accounts (adminCount = 1)
Get-ADUser -Filter 'adminCount -eq 1' -Properties adminCount | Select-Object Name, SamAccountName

# Service accounts with SPNs
Get-ADUser -Filter 'ServicePrincipalName -like "*"' -Properties ServicePrincipalName | Select-Object Name, ServicePrincipalName

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
