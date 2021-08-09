[CmdletBinding()]
param (
    $DBPath = "C:\programdata\Admin Arsenal\PDQ Inventory\Database.db",
    $Server = "http://localhost:8086",
    $Token = "",
    $Organisation = "",
    $Bucket = "",
    $PsScanID = ""
)


$Q = ".headers on
Select PSScan.*,Computers.Hostname
FROM PowerShellScanner_$($PsScanID)_View as PSSCan
INNER JOIN Computers
ON PSScan.ComputerID=Computers.ComputerID"

$Query = $Q | sqlite3.exe $DBPath | ConvertFrom-Csv -Delimiter "|"

foreach($object in $Query){
    Foreach($Item in $object.psobject.properties){
        if(($item.Name -like "*drive*") -or ($item.Name -like "*Memory*") -or ($item.Name -like "*Tempurature*") -or ($item.Name -eq "CPU Utilization") -or ($item.Name -eq "Total Processes")){
            $item.Value = [int]$item.Value
        }elseif ($item.name -eq "Timestamp") {
            $item.Value = "$(([datetimeoffset]([datetime]$item.Value)).ToUniversalTime().ToUnixTimeMilliseconds())000000"
        }
    }
}

ForEach($entry in $test){
    $HashTable = @{}
    $b = $entry | Get-Member -MemberType NoteProperty 
    foreach($property in $b) {
        $HashTable.$($property.Name) = $entry.($property.Name)
    }
    Write-Influx -Server $Server -Measure Server -Tags @{Server=$HashTable.Hostname} -Metrics $hashtable -Verbose -InfluxDB_v2 -Organisation $Organisation -Bucket $Bucket -Token $Token
}
