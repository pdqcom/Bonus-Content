$os = Get-CimInstance Win32_OperatingSystem
$build = [int]($os.Version -split '\.')[2]

if ($os.Version -like "10.0.*" -and $build -ge 22000) {
    Write-Output "Windows 11 detected: $($os.Caption) (Build $build)"


$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe"
$regName = "OutlookUpdate"

# Check if the registry key exists
if (Test-Path $regPath) {
    # Check if the registry value exists before attempting to remove it
    if (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $regPath -Name $regName -Force
        Write-Output "Registry value '$regName' removed successfully."
    } else {
        Write-Output "Registry value '$regName' does not exist."
    }
} else {
    Write-Output "Registry path '$regPath' does not exist."
}
} 

if ($os.Version -like "10.0.*" -and $build -lt 22000){
    Write-Output "$($os.Caption) (Build $build) detected"


# Define the registry path and value
$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe"
$regName = "BlockedOobeUpdaters"
$regValue = '["MS_Outlook"]'


# Ensure the registry path exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set the registry value as a REG_SZ type
Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type String

Write-Output "Registry value '$regName' set to '$regValue' successfully."

}

