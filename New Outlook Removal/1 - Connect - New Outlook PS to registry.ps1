# PowerShell Scanner
# Define the path and value

$registryPath = "HKLM:\SOFTWARE\connect_org\New_Outlook"
$valueName = "Installed"

# Create registry key if it doesn't exist
If (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

# Identify if new outlook is installed and set registry value accordingly
$Apps = Get-AppxPackage -Name "Microsoft.OutlookForWindows" -AllUsers

if ($Apps) {
    Set-ItemProperty -Path $registryPath -Name $valueName -Value 'True'
}
else {
    Set-ItemProperty -Path $registryPath -Name $valueName -Value 'False'
}