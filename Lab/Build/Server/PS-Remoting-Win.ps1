# usage
# Enables,Diables and Checks PS Remoting on Windows.
#
# Enable PS Remoting.
# .\PS-Remoting-Win.ps1 -Enable 
#
# Disable PS Remoting.
# .\PS-Remoting-Win.ps1 -Disable
#
# Check PS Remoting status
# .\PS-Remoting-Win.ps1 -Status



param (
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Status
)

# Function to check if PSRemoting is enabled and if port 5985 is listening
function Check-PSRemoting {
    # Check the WinRM service status
    $winrmStatus = Get-Service -Name WinRM -ErrorAction SilentlyContinue
 
    if ($winrmStatus.Status -eq 'Running') {
        Write-Host "PSRemoting (WinRM) is already enabled." -ForegroundColor Green
    } else {
        Write-Host "PSRemoting (WinRM) is not enabled." -ForegroundColor Yellow
    }
 
    # Check if port 5985 is listening
    $portStatus = Get-NetTCPConnection -LocalPort 5985 -State Listen -ErrorAction SilentlyContinue
 
    if ($portStatus) {
        Write-Host "Port 5985 is listening for WinRM." -ForegroundColor Green
    } else {
        Write-Host "Port 5985 is NOT listening. There might be a firewall or configuration issue." -ForegroundColor Red
    }
}

# Function to enable PS Remoting (WinRM) using built-in cmdlet
function Start-PSRemoting {
    # Check the WinRM service status
    $winrmStatus = Get-Service -Name WinRM -ErrorAction SilentlyContinue
 
    if ($winrmStatus.Status -eq 'Running') {
        Write-Host "PSRemoting (WinRM) is already enabled." -ForegroundColor Green
    } else {
        Write-Host "Enabling PS Remoting..." -ForegroundColor Yellow
        $null = Enable-PSRemoting -Force | Out-Null
        Write-Host "PSRemoting (WinRM) has been enabled." -ForegroundColor Green
    }

}

# Function to disable PS Remoting (WinRM)
function Stop-PSRemoting {
    # Stop the WinRM service
    $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
    if ($winrmService.Status -eq 'Running') {
        Write-Host "Stopping and disabling WinRM service..." -ForegroundColor Yellow
        Stop-Service -Name WinRM -Force
        Set-Service -Name WinRM -StartupType Disabled
        Write-Host "WinRM service has been stopped and disabled." -ForegroundColor Green
    } else {
        Write-Host "WinRM service is already stopped." -ForegroundColor Green
    }
    
    # Restore LocalAccountTokenFilterPolicy value to 0 (restrict remote access to admins)
    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $regValue = "LocalAccountTokenFilterPolicy"
    if (Test-Path $regKey) {
        $currentValue = (Get-ItemProperty -Path $regKey -Name $regValue -ErrorAction SilentlyContinue)
        if ($currentValue.LocalAccountTokenFilterPolicy -ne 0) {
            Write-Host "Restoring LocalAccountTokenFilterPolicy to 0..." -ForegroundColor Yellow
            Set-ItemProperty -Path $regKey -Name $regValue -Value 0
            Write-Host "LocalAccountTokenFilterPolicy has been set to 0." -ForegroundColor Green
        } else {
            Write-Host "LocalAccountTokenFilterPolicy is already set to 0." -ForegroundColor Green
        }
    } else {
        Write-Host "Registry key for LocalAccountTokenFilterPolicy not found." -ForegroundColor Red
    }
}

# Main logic based on parameters
if ($Enable) {
    Start-PSRemoting
}

if ($Disable) {
    Stop-PSRemoting
}

if ($Status) {
    Check-PSRemoting
}

if (-not ($Enable -or $Disable -or $Status)) {
    Write-Host "Please specify one of the following options: -Enable, -Disable, or -Status."
}
