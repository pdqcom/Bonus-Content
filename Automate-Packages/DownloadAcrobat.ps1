#Database Locations
$PDQDepDB = "C:\ProgramData\Admin Arsenal\PDQ Deploy\Database.db"
$PDQInvDB = "C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db"
#Get the Current Version
$oldversion = sqlite3.exe $PDQInvDB "Select Value from CustomVariables where Name = 'Acrobat';"
#Repo for this software
$Repository = "C:\Users\Public\Documents\Admin Arsenal\PDQ Deploy\Repository\Adobe\Acrobat"

#FTP Request to find the latest version
$FTPFolderUrl = "ftp://ftp.adobe.com/pub/adobe/acrobat/win/Acrobat2017/"
$FTPRequest = [System.Net.FtpWebRequest]::Create("$FTPFolderUrl") 
$FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
$FTPResponse = $FTPRequest.GetResponse()
$ResponseStream = $FTPResponse.GetResponseStream()
$FTPReader = New-Object System.IO.Streamreader -ArgumentList $ResponseStream

#take data from page and convert to useable data
$Array = New-Object System.Collections.ArrayList
$regex = '(\D{3}\s+\d{2})\s+(\S{4,5})\s(\w+)'
While ($FTPReader.EndOfStream -eq $false){
    $result = $FTPReader.ReadLine() -split $regex   
    #For some reason the last entry replaces the year with 12:12, this accounts for that
    if($result[2].Length -gt "4"){
        $result[2] = "2020"
    }
    $file = New-Object psobject -Property @{
        'lastmodified'= [datetime]($result[1] + " " + $result[2])
        'folder'= $result[3]
    }
    $Array.Add($file) | Out-Null
}
#Get Latest Version
$version = ($Array | Sort lastmodified | Select -Last 1).folder
#Adobe has all the numbers, but no dots, this adds the dots back in 
$newversion = $version.Insert(2,'.').Insert(6,'.')

#If Version has changed Downlaod and create the file
If($newversion -ne $oldversion){
    $FTPFolderUrl = "ftp://ftp.adobe.com/pub/adobe/acrobat/win/Acrobat2017/" + $Version + "/"
    $FTPRequest = [System.Net.FtpWebRequest]::Create("$FTPFolderUrl") 
    $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $FTPResponse = $FTPRequest.GetResponse()
    $ResponseStream = $FTPResponse.GetResponseStream()
    $FTPReader = New-Object System.IO.Streamreader -ArgumentList $ResponseStream
    $LatestFile = $FTPReader.ReadToEnd()
    #Create the new directory
    New-Item -Path $($Repository + "\" + $newversion) -ItemType Directory
    #Build URL to download file from FTP site
    $DownloadURL = $FTPFolderUrl + $LatestFile
    #Download file from FTP site to local file repository
    Invoke-WebRequest -Uri $DownloadURL -OutFile $($Repository + "\" + $newversion + "\" + "AcrobatUpgrade.msp")
}
