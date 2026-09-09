# Step 1 - Check Domain Functional Level (must be 2012 or higher)
Get-ADDomain | Select-Object DomainMode

# Step 2 - Create the KDS Root Key (ONE TIME PER DOMAIN - check first)
# Check if one already exists:
Get-KdsRootKey

# If none exists, create it.
# In a LAB: use -EffectiveImmediately (takes effect instantly but
# technically Microsoft says wait 10 hours in production)
Add-KdsRootKey -EffectiveImmediately

# In PRODUCTION: schedule it 10 hours in the past to be safe
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)

# Step 3 - Create a Security Group for servers allowed to use the gMSA
New-ADGroup `
    -Name "gMSA_IIS_Servers" `
    -GroupScope Global `
    -GroupCategory Security `
    -Description "Servers authorised to retrieve the IIS gMSA password"

# Step 4 - Add the member server's computer account to the group
Add-ADGroupMember `
    -Identity "gMSA_IIS_Servers" `
    -Members "MEMBERSRV01$"    # Note the $ - it is a computer account

# Step 5 - Create the gMSA
New-ADServiceAccount `
    -Name "gmsa-iis" `
    -DNSHostName "gmsa-iis.labdomain.local" `
    -PrincipalsAllowedToRetrieveManagedPassword "gMSA_IIS_Servers" `
    -Description "gMSA for IIS Application Pool on web servers"

# Verify it was created:
Get-ADServiceAccount -Identity "gmsa-iis" -Properties *

