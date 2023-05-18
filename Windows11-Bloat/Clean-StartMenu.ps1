# modified from https://gist.github.com/redlttr/8b95df51fd472d459b5c3a3ae6c8f5ad

#region install the PolicyFileEditor module to update local group policy 
Try {

    $null = Get-InstalledModule PolicyFileEditor -ErrorAction Stop

}
Catch {

    if ( -not ( Get-PackageProvider -ListAvailable | Where-Object Name -eq "Nuget" ) ) {

        $null = Install-PackageProvider "Nuget" -Force

    }

    $null = Install-Module PolicyFileEditor -Force

}

$null = Import-Module PolicyFileEditor -Force

# help about_registryvaluesforadmintemplates
# 

#endregion

# Variables
$ComputerPolicyFile = Join-Path $env:SystemRoot '\System32\GroupPolicy\Machine\registry.pol'
$UserPolicyFile = Join-Path $env:SystemRoot '\System32\GroupPolicy\User\registry.pol'

$WinVer = Get-CimInstance win32_operatingsystem

# Define policies
$ComputerPolicies = @(
    [PSCustomObject]@{Key = 'Software\Microsoft\Windows\CurrentVersion\Communications'; ValueName = 'ConfigureChatAutoInstall'; Data = '0'; Type = 'Dword' } # Disable Teams (personal) auto install (W11)
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\Windows Chat'; ValueName = 'ChatIcon'; Data = '2'; Type = 'Dword' } # Hide Chat icon by default (W11)
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\Windows Search'; ValueName = 'AllowCortana'; Data = '0'; Type = 'Dword' } # Disable Cortana
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\Windows Feeds'; ValueName = 'EnableFeeds'; Data = '0'; Type = 'Dword' } # Disable news/interests on taskbar
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\Windows Search'; ValueName = 'DisableWebSearch'; Data = '1'; Type = 'Dword' } # Disable web search in Start
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\Windows Search'; ValueName = 'AllowCloudSearch'; Data = '0'; Type = 'Dword' } # Disable web search in Start
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\CloudContent'; ValueName = 'DisableCloudOptimizedContent'; Data = '1'; Type = 'Dword' } # Disable cloud consumer content
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\CloudContent'; ValueName = 'DisableConsumerAccountStateContent'; Data = '1'; Type = 'Dword' } # Disable cloud consumer content
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\CloudContent'; ValueName = 'DisableWindowsConsumerFeatures'; Data = '1'; Type = 'Dword' } # Disable Consumer Experiences
)
  
$UserPolicies = @(
    [PSCustomObject]@{Key = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; ValueName = 'TaskbarMn'; Data = '0'; Type = 'Dword' } # Disable Chat Icon
    [PSCustomObject]@{Key = 'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; ValueName = 'HideSCAMeetNow'; Data = '1'; Type = 'Dword' } # Disable Meet Now icon (W10)
    [PSCustomObject]@{Key = 'Software\Microsoft\Windows\CurrentVersion\Search'; ValueName = 'SearchboxTaskbarMode'; Data = '1'; Type = 'Dword' } # Set Search in taskbar to show icon only 
    [PSCustomObject]@{Key = 'Software\Policies\Microsoft\Windows\CloudContent'; ValueName = 'DisableWindowsSpotlightFeatures'; Data = '1'; Type = 'Dword' } # Disable Windows Spotlight
)
  
# Set group policies
try {
    Write-Output 'Setting local group policies...'
    $ComputerPolicies | Set-PolicyFileEntry -Path $ComputerPolicyFile -ErrorAction Stop
    $UserPolicies | Set-PolicyFileEntry -Path $UserPolicyFile -ErrorAction Stop
    gpupdate /force /wait:0 | Out-Null
    Write-Output 'Group policies set.'
}
catch {
    Write-Warning 'Unable to apply group policies.'
    Write-Output $_
}
  
# Cleanup start menu & taskbar
try {
    if ($WinVer.Caption -like '*Windows 11*') {
        
      
        # Reset existing start menu layouts
        $Layout = 'AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
        Get-ChildItem 'C:\Users' | ForEach-Object { Remove-Item "C:\Users\$($_.Name)\$Layout" -Recurse -Force -ErrorAction Ignore }
  

    }
  
    # Restart Explorer 
    if ($env:USERNAME -ne 'defaultuser0') { Stop-Process -Name explorer -Force }
}
catch {
    Write-Warning 'Unable to complete start menu & taskbar cleanup tasks.'
    Write-Output $_
}
  

<#

Report on configured policies
Get-PolicyFileEntry -Path $ComputerPolicyFile -All
Get-PolicyFileEntry -Path $UserPolicyFile -All

remove the policies
Get-PolicyFileEntry -Path $ComputerPolicyFile -All | Remove-PolicyFileEntry -Path $ComputerPolicyFile

Get-PolicyFileEntry -Path $UserPolicyFile -All | Remove-PolicyFileEntry -Path $UserPolicyFile
#>