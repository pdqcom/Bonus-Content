###Define Variables
$autopath = "C:\Users\Public\Documents\Admin Arsenal\PDQ Deploy\Repository"
$autopackages = @()
$DBPath = "C:\programdata\Admin Arsenal\PDQ Deploy\Database.db"
###Build Package Objects
$mRemoteNG = New-Object psobject -Property @{
    Path = "\mRemoteNG" 
    ScheduleID = "2"
    CustomVariable = "mRemoteNG"
}   
$Acrobat = New-Object psobject -Property @{
    Path = "\Adobe\Acrobat" 
    ScheduleID = "3"
    CustomVariable = "Acrobat"
}
$Discord = New-Object psobject -Property @{
    Path = "\Discord" 
    ScheduleID = "4"
    CustomVariable = "discord"
}
###Populate Array
$autopackages += $mRemoteNG, $Acrobat, $Discord
###To core of That Thing We Are Doing
Foreach($Package in $autopackages){
###Check to see if there is a new Package to Update
    If((Get-ChildItem -Directory -Path ($autopath + $Package.path)).count -eq "3"){
###Move The old crap to the Audit Folder and Update the Variable in Inventory and Deploy
        $archive = Get-ChildItem -Directory -Path ($autopath + $Package.path) | Where{$_.name -eq "archive"} | select fullname
        Get-ChildItem -Directory -Path ($autopath + $Package.path) | Where{$_.name -ne "archive"} | sort creationtime | select -First 1 | Move-Item -Destination $archive.FullName
        $NewerVersion =  Get-ChildItem -Directory -Path ($autopath + $Package.path) | Where{$_.name -ne "archive"}
        & pdqdeploy updatecustomvariable -name $Package.CustomVariable -value $NewerVersion.Name
        & pdqinventory updatecustomvariable -name $Package.CustomVariable -value $NewerVersion.Name
###Delete Schedule History
        $SQLQuery = "Select Name FROM ScheduleComputers WHERE ScheduleId LIKE $($Package.ScheduleID)"
        $ScheduleHistory = $SQLQuery | sqlite3.exe $DBPath
        foreach($machine in $ScheduleHistory){
            & pdqdeploy DeleteScheduleHistory -Computer $machine -Schedule $Package.ScheduleID
        }
    }

}
