###Define Variables
###autopath is the location of your install files so it will know which schedule to clear
###It will put in the defauls databasepath, but you will need to change $DBpath if you have a different location 
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $autopath,

    [Parameter]
    [ValidateNotNullOrEmpty()]
    [String]
    $DBPath = "C:\programdata\Admin Arsenal\PDQ Deploy\Database.db"
)

$autopackages = @()

###Build Package Objects
$test = New-Object psobject -Property @{
    Path = "\test" 
    ScheduleID = "159"
    CustomVariable = "MyVer"
}   
$epicpen = New-Object psobject -Property @{
    Path = "\EpicPen" 
    ScheduleID = "16"
    CustomVariable = "EpicPenVer"
}
###Populate Array
$autopackages += $test, $epicpen
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
