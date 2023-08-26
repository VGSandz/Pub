############################################################################################################################
# Set the domain name
$domainName = "labone.local"

# Set the common password for all users and computers
$password = "P@ssw0rd"

# Function to create users
function Create-User {
    param (
        [string]$username,
        [string]$password,
        [string]$ouPath
    )

    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $userPrincipalName = "$username@$domainName"

    New-ADUser -Name $username -UserPrincipalName $userPrincipalName -SamAccountName $username -AccountPassword $securePassword -Enabled $true -Path $ouPath -PassThru
}

# Function to create computers
function Create-Computer {
    param (
        [string]$computerName,
        [string]$ouPath
    )

    New-ADComputer -Name $computerName -Enabled $true -Path $ouPath -PassThru
}

#Create the OUs
# Specify the domain and base distinguished name (DN)
$domain = "labone.local"
$baseDN = "DC=labone,DC=local"

#Create OU Resources
New-ADOrganizationalUnit -Name "Resources" -Path $baseDN

#Resources OU Path
$OUResourcesPath = "OU=Resources,DC=labone,DC=local"

# Create the Users OU
New-ADOrganizationalUnit -Name "Users" -Path $OUResourcesPath

# Create the Computers OU
New-ADOrganizationalUnit -Name "Computers" -Path $OUResourcesPath

# Set the OUs
$usersOU = "OU=Users,OU=Resources,DC=labone,DC=local"
$computersOU = "OU=Computers,OU=Resources,DC=labone,DC=local"

# Loop to create ten users and computers
for ($i = 1; $i -le 10; $i++) {
    $username = "Test$i"
    $computerName = "Computer$i"

    Create-User -username $username -password $password -ouPath $usersOU
    Create-Computer -computerName $computerName -ouPath $computersOU
}

############################################################################################################################
# Creation of gMSA accounts
# Import the Active Directory module
Import-Module ActiveDirectory

# Generate a new root key for KDS
$rootKey = Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))

# Confirm the root key has been added
$rootKey

# Set the GMSA names
$gmsaNames = @("GMSA_Account1", "GMSA_Account2", "GMSA_Account3", "GMSA_Account4", "GMSA_Account5")

# Loop to create the GMSA user accounts
foreach ($gmsaName in $gmsaNames) {
    # Create the GMSA user account
    New-ADServiceAccount -Name $gmsaName -DNSHostName "$gmsaName.labone.local" -SamAccountName $gmsaName -ManagedPasswordIntervalInDays 30 -PrincipalsAllowedToRetrieveManagedPassword "Domain Computers" -KerberosEncryptionType AES128,AES256
}

############################################################################################################################
