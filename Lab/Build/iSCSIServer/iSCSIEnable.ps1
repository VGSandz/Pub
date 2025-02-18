# Install iSCSI Target Server Feature
Install-WindowsFeature -Name FS-iSCSITarget-Server -IncludeManagementTools

# Add target disks

# Enable iscsi Target Service
Set-Service -Name "WinTarget" -StartupType Automatic
Start-Service -Name "WinTarget"


