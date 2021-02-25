#Database Locations
$PDQDepDB = "C:\ProgramData\Admin Arsenal\PDQ Deploy\Database.db"
$PDQInvDB = "C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db"
#Get the Current Version
$oldversion = sqlite3.exe $PDQInvDB "Select Value from CustomVariables where Name = 'mRemoteNG';"
#Repo for this software
$Repository = "C:\Users\Public\Documents\Admin Arsenal\PDQ Deploy\Repository\mRemoteNG"
#Download file name
$file = "mRemoteNG.msi"

#Git Repo Location
$GITUrl = "https://api.github.com/repos/mRemoteNG/mRemoteNG/releases/latest"
#Get Latest Version
$newversion = (Invoke-WebRequest $GITUrl | ConvertFrom-Json).assets[0].name.split("-")[2].trim(".msi")
#If Version has changed Create new folder and download installer
If($oldversion -ne $newversion){
    $DownloadURL = (Invoke-WebRequest $GITUrl | ConvertFrom-Json).assets[0].browser_download_url
    New-Item -Path $($Repository + "/" + $newversion) -ItemType Directory
    Invoke-WebRequest $DownloadURL -OutFile $($Repository + '\' + $newversion + '\' + $file)
}
