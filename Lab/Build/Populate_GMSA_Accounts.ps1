############################################################################################################################
###############################################  KDC Root Key Creation  ####################################################
###################### --- ONE TIME action to create the KDCRoot Key, If KDC Root Key exist? skip --- ######################

# Creation of gMSA accounts
# Import the Active Directory module
Import-Module ActiveDirectory

# Generate a new root key for KDS
$rootKey = Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))

# Confirm the root key has been added
$rootKey
############################################################################################################################

############################################################################################################################
################################### Populating the GMSA Accounts in the Domain #############################################
############################################################################################################################
# Set the GMSA names
$gmsaNames = @("GMSA_Account1", "GMSA_Account2", "GMSA_Account3", "GMSA_Account4", "GMSA_Account5")

# Loop to create the GMSA user accounts
foreach ($gmsaName in $gmsaNames) {
    # Create the GMSA user account
    New-ADServiceAccount -Name $gmsaName -DNSHostName "$gmsaName.labone.local" -SamAccountName $gmsaName -ManagedPasswordIntervalInDays 30 -PrincipalsAllowedToRetrieveManagedPassword "Domain Computers" -KerberosEncryptionType AES128,AES256
}

############################################################################################################################
