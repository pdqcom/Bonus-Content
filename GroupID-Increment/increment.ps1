[int]$GroupID = "Select Value FROM CustomVariables  WHERE Name LIKE 'GroupID'" | sqlite3.exe "C:\ProgramData\Admin Arsenal\PDQ Inventory\Database.db"
If($GroupID -lt "5"){
    $GroupID++
    & pdqinventory updatecustomvariable -name "GroupID" -value $GroupID
}elseif($GroupID -eq "5"){
    $GroupID= 0
    & pdqinventory updatecustomvariable -name "GroupID" -value $GroupID
}else{
    Throw "LOUD NOISES!!!!!!!!!"
}
