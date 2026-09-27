<#
.SYNOPSIS
    Populates the labdomain.info Active Directory lab: OU tree, Tier 0/1/2 +
    delegation + department groups, and a batch of demo users.

.DESCRIPTION
    Run directly on a domain controller for labdomain.info. Safe to re-run —
    OUs, groups, and users that already exist are skipped, never overwritten.

    OU tree created:

        DC=labdomain,DC=info
        |-- OU=Admin
        |   `-- OU=Groups
        |       |-- OU=Tier          (SG-Tier0/1/2-Admins)
        |       |-- OU=Delegation    (DEL-* delegation groups)
        |       `-- OU=Departments   (SG-<Dept>-All groups)
        |-- OU=Departments           (one OU per department, holds the users)
        |-- OU=ServiceAccounts       (GMSAs land here in a later video)
        `-- OU=Staging               (disabled / offboarded users)

    Groups and users live in separate branches on purpose — it makes the
    "delegate control of just this OU" much cleaner to demo.

.PARAMETER UserCount
    Total demo users to create, spread as evenly as possible across
    -Departments. Default 30.

.PARAMETER DefaultPassword
    Initial password set on every created user (ChangePasswordAtLogon = $true).
    This is a lab convenience password — do not reuse it outside a throwaway lab.

.PARAMETER Departments
    Department names. Each becomes an OU under Departments and a
    SG-<Dept>-All security group under Admin/Groups/Departments.

.PARAMETER ProtectOUs
    Whether created OUs get ProtectedFromAccidentalDeletion. Default $true.
    Set to $false while you're iterating on the lab and want to tear it down
    quickly between takes.

.EXAMPLE
    .\New-LabADPopulator.ps1
    Builds the full lab with the default 30 users.

.EXAMPLE
    .\New-LabADPopulator.ps1 -UserCount 50 -WhatIf
    Previews a 50-user run without changing anything.

.EXAMPLE
    .\New-LabADPopulator.ps1 -ProtectOUs:$false
    Builds the lab with OUs unprotected, for easy teardown/rebuild while testing.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$UserCount = 30,

    [string]$DefaultPassword = 'P@ssw0rd2026!',

    [string[]]$Departments = @('IT','HR','Finance','Sales','Marketing','Engineering','Legal'),

    [bool]$ProtectOUs = $true
)

Import-Module ActiveDirectory -ErrorAction Stop

$Domain    = Get-ADDomain
$DomainDN  = $Domain.DistinguishedName
$UPNSuffix = $Domain.DNSRoot   # labdomain.info

Write-Host "Target domain: $($Domain.DNSRoot)  ($DomainDN)" -ForegroundColor Cyan

#region Helper functions ------------------------------------------------------

function Confirm-LabOU {
    param([string]$Name, [string]$ParentDN)

    $path = "OU=$Name,$ParentDN"

    $existing = $null
    try {
        $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" `
                        -SearchBase $ParentDN -SearchScope OneLevel -ErrorAction Stop
    } catch { $existing = $null }   # parent doesn't exist yet, e.g. under -WhatIf

    if ($existing) {
        Write-Verbose "OU exists: $path"
        return $path
    }

    if ($PSCmdlet.ShouldProcess($path, "Create OU")) {
        New-ADOrganizationalUnit -Name $Name -Path $ParentDN `
            -ProtectedFromAccidentalDeletion $ProtectOUs | Out-Null
        Write-Host "Created OU: $path" -ForegroundColor Green
    }
    return $path
}

function Confirm-LabGroup {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Scope = 'Global',
        [string]$Description = ''
    )

    $existing = $null
    try {
        $existing = Get-ADGroup -Filter "Name -eq '$Name'" `
                        -SearchBase $Path -SearchScope OneLevel -ErrorAction Stop
    } catch { $existing = $null }

    if ($existing) {
        Write-Verbose "Group exists: $Name"
        return $existing
    }

    if ($PSCmdlet.ShouldProcess($Name, "Create $Scope security group")) {
        $grp = New-ADGroup -Name $Name -Path $Path -GroupScope $Scope -GroupCategory Security `
                            -Description $Description -PassThru
        Write-Host "Created group: $Name" -ForegroundColor Green
        return $grp
    }
}

#endregion ----------------------------------------------------------------------

#region 1. OU tree ---------------------------------------------------------------

$adminOU       = Confirm-LabOU -Name 'Admin'          -ParentDN $DomainDN
$adminGroupsOU = Confirm-LabOU -Name 'Groups'          -ParentDN $adminOU
$tierGroupsOU  = Confirm-LabOU -Name 'Tier'            -ParentDN $adminGroupsOU
$delGroupsOU   = Confirm-LabOU -Name 'Delegation'      -ParentDN $adminGroupsOU
$deptGroupsOU  = Confirm-LabOU -Name 'Departments'     -ParentDN $adminGroupsOU
$deptRootOU    = Confirm-LabOU -Name 'Departments'     -ParentDN $DomainDN
$svcAccountsOU = Confirm-LabOU -Name 'ServiceAccounts' -ParentDN $DomainDN
$stagingOU     = Confirm-LabOU -Name 'Staging'         -ParentDN $DomainDN

$deptOUs = @{}
foreach ($dept in $Departments) {
    $deptOUs[$dept] = Confirm-LabOU -Name $dept -ParentDN $deptRootOU
}

#endregion ------------------------------------------------------------------------

#region 2. Tier + delegation groups (groups only, no dedicated tier accounts) ------

foreach ($tier in 0,1,2) {
    Confirm-LabGroup -Name "SG-Tier$tier-Admins" -Path $tierGroupsOU `
        -Description "Tier $tier administrative rights" | Out-Null
}

Confirm-LabGroup -Name 'DEL-HelpDesk-PasswordReset' -Path $delGroupsOU `
    -Description 'Delegated: reset passwords + unlock accounts, all departments' | Out-Null
Confirm-LabGroup -Name 'DEL-GMSA-Operators' -Path $delGroupsOU `
    -Description 'Delegated: manage GMSA objects under ServiceAccounts' | Out-Null

foreach ($dept in $Departments) {
    Confirm-LabGroup -Name "DEL-$dept-UserAdmins" -Path $delGroupsOU `
        -Description "Delegated: full user management inside Departments/$dept" | Out-Null
}

#endregion ------------------------------------------------------------------------

#region 3. Department groups --------------------------------------------------------

$deptGroups = @{}
foreach ($dept in $Departments) {
    $deptGroups[$dept] = Confirm-LabGroup -Name "SG-$dept-All" -Path $deptGroupsOU `
        -Description "All members of $dept"
}

#endregion ------------------------------------------------------------------------

#region 4. Demo users ----------------------------------------------------------------

$firstNames = @('Aarav','Priya','Rohan','Sneha','Vikram','Ananya','Karan','Neha','Arjun','Divya',
                 'Rahul','Pooja','Amit','Kavya','Suresh','Meera','Ravi','Isha','Nikhil','Riya',
                 'Sanjay','Tanya','Manoj','Shreya','Deepak','Anjali','Vivek','Pallavi','Ashok','Nisha')

$lastNames  = @('Sharma','Verma','Iyer','Reddy','Nair','Gupta','Menon','Patel','Rao','Singh',
                 'Kapoor','Joshi','Chopra','Pillai','Desai','Malhotra','Bhat','Chauhan','Saxena','Agarwal')

$titlesByDept = @{
    IT          = @('Systems Administrator','Network Engineer','IT Support Specialist','Infrastructure Engineer')
    HR          = @('HR Generalist','HR Manager','Recruiter','HR Coordinator')
    Finance     = @('Financial Analyst','Accountant','Finance Manager','AP Specialist')
    Sales       = @('Sales Executive','Account Manager','Sales Manager','Business Development Rep')
    Marketing   = @('Marketing Specialist','Content Manager','Marketing Coordinator','Brand Manager')
    Engineering = @('Software Engineer','QA Engineer','DevOps Engineer','Engineering Manager')
    Legal       = @('Legal Counsel','Paralegal','Compliance Officer','Contract Manager')
}
$genericTitles = @('Staff Member','Coordinator','Specialist')

# Split UserCount across departments as evenly as possible.
$deptCount    = $Departments.Count
$baseCount    = [math]::Floor($UserCount / $deptCount)
$remainder    = $UserCount - ($baseCount * $deptCount)
$countPerDept = @{}
for ($i = 0; $i -lt $deptCount; $i++) {
    $countPerDept[$Departments[$i]] = $baseCount + ([int]($i -lt $remainder))
}

$securePwd    = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$usedSam      = @{}
$createdUsers = 0

foreach ($dept in $Departments) {

    $titlePool = if ($titlesByDept.ContainsKey($dept)) { $titlesByDept[$dept] } else { $genericTitles }

    for ($n = 1; $n -le $countPerDept[$dept]; $n++) {

        $given   = Get-Random -InputObject $firstNames
        $surname = Get-Random -InputObject $lastNames
        $sam     = ("{0}{1}" -f $given.Substring(0,1), $surname).ToLower()

        $suffix = 1
        while ($usedSam.ContainsKey($sam) -or (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
            $sam = ("{0}{1}{2}" -f $given.Substring(0,1), $surname, $suffix).ToLower()
            $suffix++
        }
        $usedSam[$sam] = $true

        $upn   = "$sam@$UPNSuffix"
        $title = Get-Random -InputObject $titlePool

        if ($PSCmdlet.ShouldProcess($sam, "Create user in $dept")) {
            New-ADUser -Name "$given $surname" `
                        -GivenName $given -Surname $surname `
                        -SamAccountName $sam -UserPrincipalName $upn `
                        -Path $deptOUs[$dept] `
                        -Department $dept -Title $title `
                        -AccountPassword $securePwd -Enabled $true `
                        -ChangePasswordAtLogon $true `
                        -PassThru | Out-Null

            Add-ADGroupMember -Identity $deptGroups[$dept] -Members $sam
            $createdUsers++
        }
    }
}

#endregion ------------------------------------------------------------------------

Write-Host ""
Write-Host "Lab populator finished." -ForegroundColor Cyan
Write-Host "  Departments:   $($Departments.Count)"
Write-Host "  Users created: $createdUsers"
Write-Host "  Default password for all created users: $DefaultPassword (ChangePasswordAtLogon = True)"
