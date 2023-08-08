<#
PSWindowsUpdates PowerShell Module Script adapted for PDQ Products
Created: 3/14/2023 C2
Updated: 5/2/2023

General Categories:
Critical Updates', 'Definition Updates', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades', 'Microsoft'

Category CategoryIDs
Application 5C9376AB-8CE6-464A-B136-22113DD69801
Connectors 434DE588-ED14-48F5-8EED-A15E09A991F6
Critical Updates E6CF1350-C01B-414D-A61F-263D14D133B4
Definition Updates E0789628-CE08-4437-BE74-2495B842F43B
Developer Kits E140075D-8433-45C3-AD87-E72345B36078
Feature Packs B54E7D24-7ADD-428F-8B75-90A396FA584F
Guidance 9511D615-35B2-47BB-927F-F73D8E9260BB
Security Updates 0FA1201D-4330-4FA8-8AE9-B877473B6441
ServicePacks 68C5B0A3-D1A6-4553-AE49-01D3A7827828
Tools B4832BD8-E735-4761-8DAF-37F882276DAB
UpdateRollups 28BC880E-0592-4CBF-8F95-C79B17911D5F
Updates CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83
Source: https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ff357803(v=vs.85)

EXAMPLE: Get all available patches from Microsoft
Get-WindowsUpdate -MicrosoftUpdate -Verbose

EXAMPLE: Exclude information:
Get-WindowsUpdate -MicrosoftUpdate -Verbose -NotCategory 'Drivers' -NotTitle 'OneDrive' -NotKBArticleID 'KB4489873'

EXAMPLE: Install updates by Category
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -Verbose -IgnoreReboot -Category 'Critical Updates', 'Security Updates', 'Updates'

EXAMPLE: Install updates by CategoryID
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -Verbose -IgnoreReboot -CategoryIDs 'E6CF1350-C01B-414D-A61F-263D14D133B4', 'CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83', '0FA1201D-4330-4FA8-8AE9-B877473B6441'

EXAMPLE: Install updates by KB number:
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -Verbose -IgnoreReboot -KBArticleID 'KB2267602', 'KB4533002'
#>

[CmdletBinding()]
param (
[Parameter(Mandatory = $true)]
[String]$KBArticleID
)
Write-Output "$KBArticleID selected to install."

$ProviderName = "NuGet"
$Module = "PSWindowsUpdate"
$RegPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate"

Write-Output "Checking if $ProviderName Provider is installed..."
IF(Get-PackageProvider -Name $ProviderName){
Write-Output "$ProviderName Provider is installed."
}
ELSE {
Write-Output "$ProviderName Provider is NOT installed."

Write-Output "Attempting to set SecurityProtocol to Tls12 for Net.ServicePointManager..."
TRY {
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
CATCH {
Write-Output "Unable to set SecurityProtocol to Tls12 for Net.ServicePointManager: $($_.Exception.Message)"
}

Write-Output "Attempting to install $ProviderName Provider..."
TRY {
Install-PackageProvider -Name $ProviderName -Force -confirm:$False
}
CATCH {
THROW "Unable to install $ProviderName Provider $($_.Exception.Message)"
}
}

Write-Output "Checking if $Module module is installed..."
IF(Get-Module -ListAvailable -Name $Module){
Write-Output "$Module module is installed."
}
ELSE{
Write-Output "$Module module is NOT Installed."
Write-Output "Attempting to install $Module module..."
TRY {
Install-Module -Name $Module -Force -Confirm:$False
}
CATCH {
THROW "Unable to install $Module module $($_.Exception.Message)"
}
}

Write-Output "Checking for Old Windows Update Registry entries..."
IF(Test-Path $RegPath){
DO {
$service = Get-Service -Name wuauserv
IF ($service.Status -eq "Stopped") {
Write-Output "The Windows Update service has been stopped."
break
} ELSE {
Write-Output "Stopping the Windows Update service..."
Stop-Service -Name wuauserv
Start-Sleep -Seconds 5
}
} UNTIL ($service.Status -eq "Stopped")

Write-Output "Removing Old Windows Update registry entries..."
Remove-Item $RegPath -Recurse
Write-Output "Windows Update Registry entries cleaned."

DO {
$service = Get-Service -Name wuauserv
IF ($service.Status -eq "Running") {
Write-Output "The Windows Update service has been started."
break
} ELSE {
Write-Output "Starting the Windows Update service..."
Start-Service -Name wuauserv
Start-Sleep -Seconds 5
}
} UNTIL ($service.Status -eq "Running")
}

Write-Output "Importing $Module Module into PowerShell session..."
TRY {
Import-Module $Module
}
CATCH {
THROW "Unable to load $Module Module into PowerShell session $($_.Exception.Message)"
}

Write-Output "Installing Selected Microsoft Updates..."
TRY {
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -Verbose -IgnoreReboot -KBArticleID $KBArticleID
}
CATCH {
THROW "$Module failed to Install Selected Microsoft Updates $($_.Exception.Message)"
}
