#Database Locations
$PDQDepDB = "C:\ProgramData\Admin Arsenal\PDQ Deploy\Database.db"
$PDQInvDB = "C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db"
#Get the Current Version
$oldversion = sqlite3.exe $PDQInvDB "Select Value from CustomVariables where Name = 'discord';"
#Repo for this software
$Repository = "C:\Users\Public\Documents\Admin Arsenal\PDQ Deploy\Repository\Discord"
#Download file name
$file = "DiscordInstall.exe"

#Get Version Number
$HTTPFolderUrl = "https://discord.com/api/download?platform=win"
$HTTPRequest = [System.Net.HttpWebRequest]::Create("$HTTPFolderUrl") 
$HTTPRequest.Method = [System.Net.WebRequestMethods+Http]::Head
$HTTPResponse = $HTTPRequest.GetResponse()
$NewVersion = $HTTPResponse.ResponseUri.localpath.Split("/")[3]

#If different then download and build folder
if($newversion -ne $oldversion){
    New-Item -Path $($Repository + "\" + $newversion) -ItemType Directory
    Invoke-WebRequest $HTTPFolderUrl -OutFile $($Repository + '\' + $newversion + '\' + $file)
}
