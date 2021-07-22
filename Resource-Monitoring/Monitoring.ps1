[CmdletBinding()]
param (
    [String[]]$Services
)
#Build Hashtable
$HT= [ordered]@{}

#TimeStamp
$date = Get-Date 
$HT.Add("TimeStamp",[datetime]$date)

#Get-Service Status
ForEach($service in $services){
        $ServiceResult = Get-Service -Name $service -ErrorAction SilentlyContinue
        if($null -eq $ServiceResult){
            $HT.Add($Service + "Service","Service does not exist")    
        }Else{
            $HT.Add($ServiceResult.Name + "Service",$ServiceResult.Status)
        }
}

#CPU Usage
$CPU = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object Average)
$HT.Add("CPU Utilization",$cpu.Average)

#Total Running Processes
$Process = (Get-Process).Count
$HT.Add("Total Processes",$Process)

#Physical Disk Info
$disks = get-physicaldisk
foreach($disk in $disks){
    $storageCounter = $disk | Get-StorageReliabilityCounter
    $HT.Add("Disk" + $($disk).DeviceID + " " + "HealthStatus",$disk.HealthStatus)
    $HT.Add("Disk" + $($disk).DeviceID + " " + "Tempurature",$storageCounter.Temperature)
    $HT.Add("Disk" + $($disk).DeviceID + " " + "Read Errors",$storageCounter.ReadErrorsTotal)
    $HT.Add("Disk" + $($disk).DeviceID + " " + "Operational Status",$disk.OperationalStatus)
}

#Logical Disk Info
$LogicalDrives = Get-psdrive -PSProvider filesystem | Where{$_.used -ne 0}
Foreach($LogicalDrive in $LogicalDrives){
    $total = (($LogicalDrive).free + ($LogicalDrive).used)
    $HT.Add(($LogicalDrive).Name + " " + "Drive" + " " + "Used(gb)",[math]::round($LogicalDrive.Used / 1gb, 2))
    $HT.Add(($LogicalDrive).Name + " " + "Drive" + " " + "Free(gb)",[math]::round($LogicalDrive.Free / 1gb, 2))
    $HT.Add(($LogicalDrive).Name + " " + "Drive" + " " + "% Free",[math]::round(($LogicalDrive.Free / $total) * 100, 2))
}

#Memory Info
$Memory = Get-CimInstance -ClassName Win32_OperatingSystem
$HT.Add("Free Memory(gb)",[Math]::Round($Memory.FreePhysicalMemory / 1mb, 2))
$HT.Add("Total Memory (gb)",[Math]::Round($Memory.TotalVisibleMemorySize / 1mb, 2))
$HT.Add("Free Memory (%)",[Math]::Round(($Memory.FreePhysicalMemory/$Memory.TotalVisibleMemorySize)* 100, 2))

#Build Custom Object
[PSCustomObject]$HT
