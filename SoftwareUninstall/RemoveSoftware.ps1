#Application names, If everything is only as an asterisk it will attempt to remove everything...be careful
$AppName = "*Software Example*", "*Other Example*"

#Publisher names
$Publisher = "*", "*"

#Version numbers
$Version = "*", "*"

#Non-MSI silent parameters
$Silent = "", ""

#MSI silent paramaters
$MSISilent = "/QN /NORESTART"

#Add application criteria to hashtables in an array
$Array = @()
$count = [int]0
Foreach($option in $appname){ 
    $App = @{'App' = $AppName[$count]; 'Publisher'=$Publisher[$count]; 'Version'=$Version[$count]; 'Silent'=$Silent[$count]}
    $Newobject = New-Object PSObject -Property $App
    $Array += $Newobject
    $Count ++
}
$Array2 = @()

$Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

Foreach($App in $Array){

    #Search for Application that meet the criteria
    $Search = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object {$_.DisplayName -like $App.app -and $_.Publisher -like $App.publisher -and $_.version -like $App.version }
    $search | Add-Member -MemberType NoteProperty -Name "SilentParams" -Value $app.Silent
    $Array2 += $Search
   
}

Foreach($Found in $Array2){

        #Use parameters in the UninstallString key + Non-MSI silent parameters
        $DisplayName = $Found.DisplayName



        If ($Found.UninstallString -notmatch "MsiExec.exe*" -and $Found.UninstallString -ne $Null){
        
            #Show the Name and Uninstall String
            Write-Output =================================================================================================
            Write-Output "Uninstalling: $DisplayName"
            Write-Output -------------------------------------------------------------------------------------------------
            Write-Output "$($Found.Uninstallstring) $($Found.SilentParams)"
            Write-Output =================================================================================================
                         
            #Uninstall
            $RunCommand = [diagnostics.process]::start("cmd.exe", "/c `"$($Found.UninstallString)`" $($Found.SilentParams)")
            $RunCommand.waitforexit();

            #Verify that it is gone
            $Product = Get-WmiObject -Class Win32_Product | Where {$_.Name -like $Found.displayname}

            If ($Product.Name){
                Write-Output "Uninstall was unsuccesfull on ($Env:COMPUTERNAME)"
            }
            Else {
                Write-Output "Uninstall was succesfull on ($Env:COMPUTERNAME)"
            }

        } 

        #MSI uninstallers + MSI silent paramaters
        If ($Found.UninstallString -match "MsiExec.exe*" -and $Found.UninstallString -ne $Null){

            #Show the Name and Uninstall String
            $Uninstall = $Found.UninstallString -replace "/I", "/X" -replace "msiexec.exe ",""
            $Final = "$($Uninstall) $MSISilent"
            Write-Output =================================================================================================
            Write-Output "Uninstalling: $DisplayName"
            Write-Output -------------------------------------------------------------------------------------------------
            Write-Output "MsiExec.exe $Uninstall $MSISilent"
            Write-Output =================================================================================================
                         
            #Uninstall 
            $RunCommand = [diagnostics.process]::start("MsiExec.exe", $Final)
            $RunCommand.waitforexit();

            #Verify that it is gone
            $Product = Get-WmiObject -Class Win32_Product | Where {$_.Name -like $Found.displayname}

            If ($Product.Name){
                Write-Output "Uninstall was unsuccesfull on ($Env:COMPUTERNAME)"
            }
            Else {
                Write-Output "Uninstall was succesfull on ($Env:COMPUTERNAME)"
            }

        }

    }
