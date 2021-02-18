 param(
    [string]$File = "C:\temp\countdown.txt"
 )

IF(Test-Path $File){

[PSCustomObject]@{
        Name = (Get-ChildItem $File).Name
        LastEdit = (Get-ChildItem $File).LastWriteTime       
        CurrentCount = Get-Content $File
    }
 }
