# Define the registry path and value
$regPath = "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences"
$regName = "NewOutlookMigrationUserSetting"
$regValue = 0

# Ensure the registry path exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type DWord

Write-Output "Registry value '$regName' set to '$regValue' successfully."
