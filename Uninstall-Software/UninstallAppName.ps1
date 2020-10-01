$64BitProgramsList = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty
$32BitProgramsList = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty
$CurrentUserProgramsList = Get-ChildItem "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty
<#These are the uninstall registry keys which correspond to currently installed programs and contain the uninstall command.#>


$ProgramName = @(
    [pscustomobject]@{displayname = "Mobaxterm"; silent = "/quiet"}
    [pscustomobject]@{displayname = "KeePass Password Safe*"; silent = "/VerySilent"}
    [pscustomobject]@{displayname = "Meld"; silent = "/qn"}
)
<#Program name strings to search for, you can specify multiple by seperating them with a comma.
Don't use wildcard characters unless the application name contains the wild card character, as these will will be used in a regular expressions match.#>


$SearchList = $32BitProgramsList + $64BitProgramsList
<#Program lists to search in, you can specify multiple by adding them together.#>


$Programs = $SearchList | Where-Object{$_.DisplayName -match ($ProgramName.displayname -join "|")}
Write-Output "Programs Found: $($Programs.DisplayName -join ", ")`n`n"

$array = @()
foreach($Program in $Programs){
    foreach($item in $ProgramName){
        if($Program.displayname -like $item.displayname){
           if($Program.UninstallString -like "*/I*"){$Program.UninstallString = $Program.UninstallString -replace "/I","/X"} 
            $array += $Program | Select Displayname, PSPath, InstallLocation, @{Name = 'silent'; Expression={$Program.uninstallstring + ' ' + $Item.Silent}}
        }
    }
}


Foreach ($Program in $array){
    If (Test-Path $Program.PSPath){
        Write-Output "Registry Path: $($Program.PSPath | Convert-Path)"
        Write-Output "Installed Location: $($Program.InstallLocation)"
        Write-Output "Program: $($Program.DisplayName)"
        Write-Output "Uninstall Command: $($Program.silent)"

        $Uninstall = (Start-Process cmd.exe -ArgumentList '/c', $Program.Silent -Wait -PassThru)
<#Runs the uninstall command located in the uninstall string of the program's uninstall registry key, this is the command that is ran when you uninstall from Control Panel.
If the uninstall string doesn't contain the correct command and parameters for silent uninstallation, then when PDQ Deploy runs it, it may hang, most likely due to a popup.#>

    Write-Output "Exit Code: $($Uninstall.ExitCode)`n"
    If ($Uninstall.ExitCode -ne 0){
        Exit $Uninstall.ExitCode
    }
<#This is the exit code after running the uninstall command, by default 0 means succesful, any other number may indicate a failure, so if the exit code is not 0, it will cause the script to exit.
The exit code is dependent on the software vendor, they decide what exit code to use for success and failure, most of the time they use 0 as success, but sometimes they don't.#>
    }Else{
        Write-Output "Registry key for ($($Program.DisplayName)) no longer found, it may have been removed by a previous uninstallation.`n"
        }
}

If (!$Programs){
    Write-Output "No Program found!"
}
