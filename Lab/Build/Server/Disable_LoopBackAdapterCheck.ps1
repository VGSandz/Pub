$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$propertyName = "DisableLoopbackCheck"
   
# Check if the DisableLoopbackCheck key exists
$propertyExists = Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction SilentlyContinue
   
if ($propertyExists -eq $null) {
    # If it doesn't exist, create it as a REG_DWORD with a value of 0
    New-ItemProperty -Path $registryPath -Name $propertyName -PropertyType DWORD -Value 1
    Write-Output "Created $propertyName with value 1"
} elseif ($propertyExists.DisableLoopbackCheck -eq 1) {
    # If it exists, output the current value
    $currentValue = $propertyExists.$propertyName
    Write-Output "$propertyName currently exists with value $currentValue"
  }
  else
  {
    # Update its value to 0
    Set-ItemProperty -Path $registryPath -Name $propertyName -Value 1
    Write-Output "Updated $propertyName to value 1"
}
