###Enter the server and zone you are looking to clean up.
###This assumes your VPN reservations are in the same zone, if it is in multiple you will need to account for that.
###This will also remove the PTR record so please add the reverse lookup zone.
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $DnsServer,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $DnsZone,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $DnsReverseZone,

    [UInt32]
    $PingCount = 1,

    [Switch]
    $Force,

    [Switch]
    $AllIPs
)

###This will get your scavenging settings. As it is currently written it will only pull records that have data outside these numbers.
$ZoneAging = Get-DnsServerZoneAging -Name $DnsZone -ComputerName $DnsServer
$TotalTime = $ZoneAging.NoRefreshInterval.Days + $ZoneAging.RefreshInterval.Days

###This grabs the records. If you want to run this against all IPs (not just the older records), add the -AllIPs parameter.
###If you do that it will delete the records of every machine that does not respond to a ping. Be very sure you want this, and test it first!
$StaleRecords = Get-DnsServerResourceRecord -ComputerName $DnsServer -RRType "A" -ZoneName $DnsZone
if (-not $AllIPs) {
    $StaleRecords = $StaleRecords | Where-Object { $_.TimeStamp -and ($_.Timestamp -le (Get-Date).AddDays(-$TotalTime)) }
}

###This will ping every address. If it does not respond it will look up the A and PTR records and remove them.
###By default these commands will be run with the -WhatIf parameter. In order to actually remove the records, add the -Force parameter.
ForEach ($Record in $StaleRecords) {
    $RespondToPing = Test-Connection $Record.HostName -Quiet -Count $PingCount
    If (-not $RespondToPing) {
        $PtrRecord = Get-DnsServerResourceRecord -ComputerName $DnsServer -RRType "Ptr" -ZoneName $DnsReverseZone
        $PtrRecord = $PtrRecord | Where-Object { $_.RecordData.PtrDomainName -like ($Record.Hostname + "*") }

        $ParamsRemoveA = @{
            ComputerName = $DnsServer
            Name         = $Record.Hostname
            RRType       = "A"
            ZoneName     = $DnsZone
        }
        $ParamsRemovePtr = @{
            ComputerName = $DnsServer
            Name         = $PtrRecord.Hostname
            RRType       = "Ptr"
            ZoneName     = $DnsReverseZone
        }
        if ($Force) {
            $ParamsRemoveA.Force = $true
            $ParamsRemovePtr.$Force = $true
        } else {
            $ParamsRemoveA.WhatIf = $true
            $ParamsRemovePtr.WhatIf = $true
        }
        Remove-DnsServerResourceRecord @ParamsRemoveA
        Remove-DnsServerResourceRecord @ParamsRemovePtr
    }
}