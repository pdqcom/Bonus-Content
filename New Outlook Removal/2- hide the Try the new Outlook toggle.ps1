# Define the registry path and value
$regPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
$regName = "HideNewOutlookToggle"
$regValue = 0

# Ensure the registry path exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set the registry value
Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type DWord
