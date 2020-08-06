##Get appx Packages
$Packages = Get-AppxPackage

##Create Your Whitelist
$Whitelist = @(
    '*WindowsCalculator*',
    '*MSPaint*',
    '*Office.OneNote*',
    '*Microsoft.net*',
    '*MicrosoftEdge*',
    '*WindowsStore*'
)

###Get All Dependencies
ForEach($Dependency in $Whitelist){
    (Get-AppxPackage -AllUsers -Name "$Dependency").dependencies | Foreach{
        $NewAdd = "*" + $_.Name + "*"
        if($_.name -ne $null -and $Whitelist -notcontains $NewAdd){
            $Whitelist += $NewAdd
       }
    }
}

##View all applications not in your whitelist
ForEach($App in $Packages){
    $Matched = $false
    Foreach($Item in $Whitelist){
        If($App -like $Item){
            $Matched = $true
            break
        }
    }
    ###Nonremovable attribute does not exist before 1809, so if you are running this on an earlier build remove "-and $app.NonRemovable -eq $false" rt it will attempt to remove everything
    if($matched -eq $false -and $app.NonRemovable -eq $false){
        Get-AppxPackage -AllUsers -Name $App.Name -PackageTypeFilter Bundle  | Remove-AppxPackage -AllUsers
    }
}
