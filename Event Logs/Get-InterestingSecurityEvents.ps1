# Define a hashtable of log names and their interesting event IDs
$EventIdMap = @{
    'Security' = @(1102, 4616, 4618, 4624, 4625, 4648, 4649, 4656, 4657, 4663, 4670, 4672, 4688, 4689, 4697,
                   4698, 4699, 4700, 4701, 4702, 4719, 4720, 4722, 4723, 4724, 4725, 4735, 4737, 4738, 4740,
                   4771, 4776, 5140, 5142, 5145, 5157)
    'System' = @(7045)
    'Microsoft-Windows-Windows Defender/Operational' = @(1116, 1118, 1119, 5001)
}

# Loop through each log and query matching event IDs
$output = foreach ($log in $EventIdMap.Keys) {
    $ids = $EventIdMap[$log]

    foreach ($id in $ids) {
        try {
            Write-Verbose "Log: $log | Event ID: $id" -Verbose
            Get-WinEvent -FilterHashtable @{ LogName = $log; Id = $id } -MaxEvents 25 -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to query Event ID $id from $log $_"
        }
    }
}

$Output
