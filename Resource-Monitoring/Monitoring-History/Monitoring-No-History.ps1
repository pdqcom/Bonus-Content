[CmdletBinding()]
param (
    [String[]]$Services,
    [String[]]$Processes,
    [int[]]$Ports,
    [int]$EventTimeFrame = 15
)
#Build Hashtable
$HT = [ordered]@{}

#TimeStamp
$date = Get-Date 
$HT.Add("TimeStamp",$date)

#Get-Service Status
ForEach($service in $services){
        $ServiceResult = Get-Service -Name $service -ErrorAction SilentlyContinue
        if($null -eq $ServiceResult){
            $HT.Add($Service + "Service","Service does not exist")    
        }Else{
            $HT.Add($ServiceResult.Name + "Service",$ServiceResult.Status)
        }
}

#Get Process Information
ForEach($Process in $Processes){
    $ProcessResult = Get-Process -Name $Process -ErrorAction SilentlyContinue
    if($null -eq $ProcessResult){
        $HT.Add($Process + " Process ID",0)    
    }Else{
        $HT.Add($Process + " " + "Process ID",$ProcessResult.Id)
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
$LogicalDrives = Get-psdrive -PSProvider filesystem | Where-Object{$_.used -ne 0}
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

#Getting logon Events
$UserArray = New-Object System.Collections.ArrayList
$EventArray = @()
$TimeFrame = (Get-Date).AddMinutes(-($EventTimeFrame))
Get-EventLog -LogName "Security" -InstanceId 4624 -ErrorAction "SilentlyContinue" | Where-Object{$_.TimeGenerated -gt $TimeFrame} | ForEach-Object {

    $EventMessage = $_
    $AccountName = $EventMessage.ReplacementStrings[5]
    $LogonType = $EventMessage.ReplacementStrings[8]

    # Look for events that contain local or remote logon events, while ignoring Windows service accounts
    if (($LogonType -in "2", "10"  ) -and ( $AccountName -notmatch "^(DWM|UMFD)-\d"))  {
        # Skip duplicate names
        if ( $UserArray -notcontains $AccountName ) {
            $null = $UserArray.Add($AccountName)
            # Translate the Logon Type
            if ( $LogonType -eq "2" ) {
                $LogonTypeName = "Local"
            } elseif ( $LogonType -eq "10" ) {
                $LogonTypeName = "Remote"
            }
            # Build an object containing the Username, Logon Type, and Last Logon time
            $EventArray += $AccountName + " " + $LogonTypeName + " " + [DateTime]$EventMessage.TimeGenerated.ToString("yyyy-MM-dd HH:mm:ss") 
        }
    }
}
$EventArray = ($EventArray | Out-String).Trim()
$ht.Add("LogonEvents", $EventArray)

#Test Ports
foreach($Port in $Ports){
    Try{
        New-Object System.Net.Sockets.TcpClient("localhost", $Port) | Out-Null
        $PortTest = "Open"
    }catch{
        $PortTest = "Closed"
    }
    $HT.Add("Port" + $Port,$PortTest)
}
#Build Custom Object
[PSCustomObject]$HT
