 ###Create Labels
 param(
 [string]$CountdownFile = "C:\temp\countdown.txt",
 [int]$Attempts = 4,
 [int]$Timeout = 360
 )
 
 ###Get Number of Attempts until it will install anyway
 If(Test-Path $CountdownFile){
    $Attempts = (Get-Content $CountdownFile) - 1
 }

###If attempts equals zero, kick off update, if between 1-5 Alert User.
If($attempts -gt 0){
    $Message = "We are going to Install/Update some software, are you ready? If you select No you we will ask again in an hour. You can delay the install $Attempts more time(s)."
    $shell = new-object -comobject wscript.shell
    $popup = $shell.popup($Message,$Timeout,"Software Updates",4)
}Else{
    $Message = "You are out of delays, we are installing"
    $shell = new-object -comobject wscript.shell
    $popup = $shell.popup($Message,$Timeout,"Software Updates",0)
}

switch  ($popup){
    '1'{
    ###If countdown has reached 0 then 1 is the response for hitting ok
        If(Test-Path $CountdownFile){
            Remove-Item $CountdownFile -Force
        }
    }
    '6'{
    ###If user clicks on Yes then do this
        If(Test-Path $CountdownFile){
            Remove-Item $CountdownFile -Force
        }
    }
    '7'{
    ###If User clicks No Then do this
        If(Test-Path $CountdownFile){
            $Count = Get-Content $CountdownFile
            $Count -1 | Set-Content $CountdownFile -Force
            Exit 654
        }Else{
            New-Item $CountdownFile -Force | Out-Null
            Set-Content $CountdownFile $Attempts
            Exit 654
        }
    }
    '-1'{
    ###If Timeout lapses then do this
        If(Test-Path $CountdownFile){
            Remove-Item $CountdownFile -Force
        }
    }
}
