###Name of the Application Variable
$AppNameVar = Read-Host "Type in name of Variable"
###Application Name
$AppNameValue = Read-Host "Application Name?"
###Name of the Application Version Variable
$AppVerVar = Read-Host "Version Variable Name?"
###Application Version
$AppVerValue = Read-Host "Application Version"

###Create Filename
$FileName = $AppNameValue + ".xml"
###Get Exsiting XML and replace placeholder information with params
$file = Get-Content -Path "$PSScriptRoot\Name of your Application.xml" | ForEach-Object{$_.replace("AppNameApp",$AppNameVar).Replace("AppVerApp","$AppVerVar").replace("Name of your Application","$AppNameValue").replace("Version of your Application","$AppVerValue")}
###Export new xml
$FinalExport = [xml]$file
$FinalExport.'AdminArsenal.Export'.InnerXml | Out-File -FilePath "C:\temp\$FileName"