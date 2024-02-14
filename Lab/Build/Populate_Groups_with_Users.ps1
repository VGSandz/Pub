# Define variables
$GroupName = "Domain Admins"
$Users = "Test1", "Test2", "Test3", "Test4", "Test5"

# Check if the group exists
if (Get-ADGroup -Filter {Name -eq $GroupName})
{
    Write-Host "Group '$GroupName' exists."
    # Check if each user exists and add them to the group
    foreach ($user in $Users)
    {
        if (Get-ADUser -Filter {SamAccountName -eq $user})
        {
            #Add user to the defined Group.
            Add-ADGroupMember -Identity $GroupName -Members $user
            Write-Host "Added user '$user' to group '$GroupName'."
        }
        else
        {
            Write-Warning "User '$user' does not exist."
        }
    }
}
else
{
    Write-Warning "Group '$GroupName' does not exist."
}
