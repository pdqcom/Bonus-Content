#requires -Version 5.1
<#
.SYNOPSIS
    Read-only Windows endpoint troubleshooting and health snapshot.

.DESCRIPTION
    Produces consistent PSCustomObject rows suitable for local use, PDQ Connect,
    and other endpoint-management tools. The default output is a single compact
    text table suitable for a PDQ Connect output log. Use -VerboseStandalone to
    include individual recent events, local users, modules, adapters, software
    detections, and file findings.

    This script makes no configuration changes and never reads file contents.

.PARAMETER VerboseStandalone
    Adds individual event, user, adapter, module, and other detailed result rows.

.PARAMETER ConsoleOutput
    Writes a grouped, color-coded report for interactive use. Without this
    switch, the script emits a compact table for PDQ Connect.

.PARAMETER ObjectOutput
    Emits the summary, category rollups, and detailed results as structured
    PSCustomObject rows instead of the default compact table.

.PARAMETER IssuesOnly
    Limits displayed detailed results to WARN, FAIL, and ERROR. Summary counts
    still describe the complete health-check run.

.EXAMPLE
    .\EndpointHealthCheck.ps1 -ConsoleOutput

    Displays the concise color-coded report.

.EXAMPLE
    .\EndpointHealthCheck.ps1 -ConsoleOutput -VerboseStandalone

    Displays the color-coded report with expanded details.

.EXAMPLE
    .\EndpointHealthCheck.ps1 -IssuesOnly

    Displays one compact PDQ Connect table containing only actionable results.
#>
[CmdletBinding()]
param(
    [switch]$VerboseStandalone,
    [switch]$ConsoleOutput,
    [switch]$ObjectOutput,
    [switch]$IssuesOnly
)

# -----------------------------------------------------------------------------
# Configuration - edit these values for your environment.
# -----------------------------------------------------------------------------
$Configuration = @{
    MinimumRamGB            = 8
    MinimumFreeDiskGB       = 20
    CriticalFreeDiskGB      = 10
    MinimumFreeDiskPercent  = 15
    CriticalDiskPercent     = 5
    MaximumUptimeDays       = 30
    ApprovedLocalAdmins     = @(
        'Administrator'
        'DOMAIN\Endpoint Admins'
    )
    RequiredSoftware        = @(
        @{
            Name           = 'PDQ Connect Agent'
            Match          = @('PDQConnectAgent', 'PDQ Connect Agent*')
            MinimumVersion = $null
        }
        @{
            Name           = 'PowerShell 7'
            Match          = @('PowerShell 7*')
            Paths          = @('C:\Program Files\PowerShell\7\pwsh.exe')
            MinimumVersion = $null
        }
        @{
            Name           = 'Microsoft Outlook'
            Match          = @('Microsoft Outlook*')
            Paths          = @(
                'C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE'
                'C:\Program Files (x86)\Microsoft Office\root\Office16\OUTLOOK.EXE'
            )
            AppxName       = 'Microsoft.OutlookForWindows'
            MinimumVersion = $null
        }
    )
    RequiredServices        = @(
        @{ Name = 'PDQConnectAgent'; RequiredState = 'Running'; RequiredStartType = 'Automatic' }
        @{ Name = 'EventLog'; RequiredState = 'Running'; RequiredStartType = 'Automatic' }
        @{ Name = 'Winmgmt'; RequiredState = 'Running'; RequiredStartType = 'Automatic' }
        @{ Name = 'Dnscache'; RequiredState = 'Running'; RequiredStartType = 'Automatic' }
    )
    RequiredShortcuts       = @(
        @{ Name = 'Employee Portal'; Path = 'C:\Users\Public\Desktop\Employee Portal.lnk' }
    )
    RequiredPaths           = @(
        @{ Name = 'Employee Handbook'; Path = '{UserProfile}\Documents\Employee Handbook.txt'; Type = 'Leaf' }
    )
    ExpectedHostnamePattern = '^(LAP|DESK)-[A-Z0-9]{6,12}$'
    MaximumDownloadsGB      = 10
    MaximumDesktopFiles     = 100
    MaximumVsCodeExtensions = 50
    RecentEventCount        = 8
    EventLookbackDays       = 14
    SupportedWindowsBuilds  = @(
        '10.0.26100' # Windows 11 24H2
        '10.0.26200' # Windows 11 25H2
        '10.0.28000' # Windows 11 26H1 (new-device release)
    )
    DnsTestName             = 'www.microsoft.com'
}

$script:Results = [System.Collections.Generic.List[object]]::new()

function Add-HealthResult {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('PASS', 'INFO', 'WARN', 'FAIL', 'ERROR', 'NA')][string]$Status,
        [AllowNull()][object]$Expected,
        [AllowNull()][object]$Actual,
        [AllowNull()][object]$Details
    )

    $script:Results.Add([PSCustomObject][ordered]@{
        Category = $Category
        Check    = $Check
        Status   = $Status
        Expected = $Expected
        Actual   = $Actual
        Details  = $Details
    })
}

function Add-CheckError {
    param([string]$Category, [string]$Check, [System.Management.Automation.ErrorRecord]$ErrorRecord)
    Add-HealthResult -Category $Category -Check $Check -Status 'ERROR' -Expected $null -Actual 'Check could not be completed' -Details $ErrorRecord.Exception.Message
}

function Write-ConsoleLine {
    param(
        [AllowEmptyString()][string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    try {
        $previousColor = $Host.UI.RawUI.ForegroundColor
        $Host.UI.RawUI.ForegroundColor = $Color
        $Host.UI.WriteLine($Text)
        $Host.UI.RawUI.ForegroundColor = $previousColor
    }
    catch {
        $Host.UI.WriteLine($Text)
    }
}

function Show-ConsoleReport {
    param(
        [object[]]$Summary,
        [object[]]$CategorySummary,
        [object[]]$Results,
        [switch]$IncludeDetails
    )

    $statusColors = @{
        PASS  = [ConsoleColor]::Green
        INFO  = [ConsoleColor]::Gray
        WARN  = [ConsoleColor]::Yellow
        FAIL  = [ConsoleColor]::Red
        ERROR = [ConsoleColor]::Red
        NA    = [ConsoleColor]::DarkGray
    }

    $overall = $Summary | Where-Object Check -eq 'Overall Health' | Select-Object -First 1
    Write-ConsoleLine ''
    Write-ConsoleLine "Endpoint Health Check - $env:COMPUTERNAME" Cyan
    Write-ConsoleLine ('=' * 72) DarkGray
    Write-ConsoleLine "Overall Health: $($overall.Actual)" $statusColors[$overall.Status]

    $summaryParts = foreach ($name in @('Total Checks', 'Passed', 'Warnings', 'Failures', 'Errors', 'Informational', 'Not Applicable')) {
        $item = $Summary | Where-Object Check -eq $name | Select-Object -First 1
        if ($item) { "$name=$($item.Actual)" }
    }
    Write-ConsoleLine ($summaryParts -join ' | ') White

    Write-ConsoleLine ''
    Write-ConsoleLine 'Category Summary' Cyan
    Write-ConsoleLine ('-' * 72) DarkGray
    foreach ($category in $CategorySummary) {
        $line = '[{0,-5}] {1,-24} {2}' -f $category.Status, $category.Check, $category.Actual
        Write-ConsoleLine $line $statusColors[$category.Status]
    }

    Write-ConsoleLine ''
    Write-ConsoleLine 'Detailed Results' Cyan
    Write-ConsoleLine ('-' * 72) DarkGray
    foreach ($group in $Results | Group-Object Category) {
        Write-ConsoleLine ''
        Write-ConsoleLine $group.Name Cyan
        foreach ($result in $group.Group) {
            $actual = if ($null -eq $result.Actual -or [string]::IsNullOrWhiteSpace([string]$result.Actual)) { '-' } else { [string]$result.Actual }
            $line = '  [{0,-5}] {1}: {2}' -f $result.Status, $result.Check, $actual
            Write-ConsoleLine $line $statusColors[$result.Status]

            if ($IncludeDetails -or $result.Status -in @('WARN', 'FAIL', 'ERROR')) {
                if ($null -ne $result.Expected -and -not [string]::IsNullOrWhiteSpace([string]$result.Expected)) {
                    Write-ConsoleLine "          Expected: $($result.Expected)" DarkGray
                }
                if ($null -ne $result.Details -and -not [string]::IsNullOrWhiteSpace([string]$result.Details)) {
                    Write-ConsoleLine "          Details:  $($result.Details)" DarkGray
                }
            }
        }
    }
    Write-ConsoleLine ''
}

function ConvertTo-TableCell {
    param(
        [AllowNull()][object]$Value,
        [int]$Width
    )

    $text = if ($null -eq $Value) { '-' } else { [string]$Value }
    $text = ($text -replace '[\r\n\t]+', ' ' -replace '\s{2,}', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { $text = '-' }

    if ($text.Length -gt $Width) {
        $text.Substring(0, $Width - 3) + '...'
    } else {
        $text
    }
}

function New-ConnectReport {
    param(
        [object[]]$Summary,
        [object[]]$Results
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $overall = $Summary | Where-Object Check -eq 'Overall Health' | Select-Object -First 1
    $lines.Add("Endpoint Health Check - $env:COMPUTERNAME")
    $lines.Add("Overall Health: $($overall.Actual)")

    $summaryParts = foreach ($name in @('Total Checks', 'Passed', 'Warnings', 'Failures', 'Errors', 'Informational', 'Not Applicable')) {
        $item = $Summary | Where-Object Check -eq $name | Select-Object -First 1
        if ($item) { "$name=$($item.Actual)" }
    }
    $lines.Add($summaryParts -join ' | ')
    $totalItem = $Summary | Where-Object Check -eq 'Total Checks' | Select-Object -First 1
    $lines.Add("Displayed Results: $($Results.Count) of $($totalItem.Actual)")
    $lines.Add('')

    $header = '{0,-5}  {1,-20}  {2,-36}  {3,-68}' -f 'STATE', 'CATEGORY', 'CHECK', 'RESULT'
    $lines.Add($header)
    $lines.Add('-' * 137)

    foreach ($result in $Results) {
        $status = ConvertTo-TableCell $result.Status 5
        $category = ConvertTo-TableCell $result.Category 20
        $check = ConvertTo-TableCell $result.Check 36
        $actual = ConvertTo-TableCell $result.Actual 68
        $lines.Add(('{0,-5}  {1,-20}  {2,-36}  {3,-68}' -f $status, $category, $check, $actual))
    }

    $lines -join [Environment]::NewLine
}

function Get-RegistryValueSafe {
    param([string]$Path, [string]$Name)
    try {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        [PSCustomObject]@{ Found = $true; Value = $item.$Name; Error = $null }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        [PSCustomObject]@{ Found = $false; Value = $null; Error = $null }
    }
    catch {
        [PSCustomObject]@{ Found = $false; Value = $null; Error = $_.Exception.Message }
    }
}

function Add-RegistryResult {
    param(
        [string]$Check,
        [string]$Path,
        [string]$Name,
        [string]$Status,
        [object]$Expected,
        [object]$Actual,
        [string]$Explanation
    )
    $detail = "RegistryPath=$Path; ValueName=$Name; $Explanation"
    Add-HealthResult -Category 'Windows Settings' -Check $Check -Status $Status -Expected $Expected -Actual $Actual -Details $detail
}

function ConvertTo-ShortText {
    param([AllowNull()][string]$Text, [int]$MaximumLength = 240)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        $null
    } else {
        $oneLine = ($Text -replace '[\r\n\t]+', ' ' -replace '\s{2,}', ' ').Trim()
        if ($oneLine.Length -le $MaximumLength) {
            $oneLine
        } else {
            $oneLine.Substring(0, $MaximumLength - 3) + '...'
        }
    }
}

function Get-FolderSizeGB {
    param([string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            $null
        } else {
            $bytes = (Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            if ($null -eq $bytes) { $bytes = 0 }
            [math]::Round($bytes / 1GB, 2)
        }
    }
    catch { $null }
}

function Get-InstalledSoftware {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $items = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) } |
            Select-Object @{ Name = 'Name'; Expression = { $_.DisplayName } },
                @{ Name = 'Version'; Expression = { $_.DisplayVersion } }, Publisher
    }
    @($items | Sort-Object Name, Version -Unique)
}

function Get-CommandDetail {
    param([string[]]$Names, [string[]]$VersionArguments = @('--version'))
    $detail = $null
    foreach ($name in $Names) {
        if ($detail) { continue }
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            $version = $null
            try { $version = ConvertTo-ShortText -Text ((& $command.Source @VersionArguments 2>&1 | Select-Object -First 1) -as [string]) -MaximumLength 120 } catch {}
            $detail = [PSCustomObject]@{ Found = $true; Path = $command.Source; Version = $version }
        }
    }
    if ($detail) {
        $detail
    } else {
        [PSCustomObject]@{ Found = $false; Path = $null; Version = $null }
    }
}

function Get-UserProfiles {
    try {
        @(Get-CimInstance Win32_UserProfile -ErrorAction Stop |
            Where-Object { -not $_.Special -and $_.LocalPath -and (Test-Path -LiteralPath $_.LocalPath) } |
            Select-Object -ExpandProperty LocalPath -Unique)
    }
    catch {
        @(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
            Select-Object -ExpandProperty FullName)
    }
}

# Execution context
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Add-HealthResult 'Execution' 'Run Context' 'INFO' $null $identity.Name "Elevated=$isElevated; UserProfile=$env:USERPROFILE"
    if (-not $isElevated) {
        Add-HealthResult 'Execution' 'Elevation' 'WARN' 'Elevated for complete results' 'Not elevated' 'Restricted checks may produce ERROR or NA; the script will continue.'
    } else {
        Add-HealthResult 'Execution' 'Elevation' 'PASS' 'Elevated for complete results' 'Elevated' $null
    }
}
catch { Add-CheckError 'Execution' 'Run Context' $_ }

# Hardware and storage
try {
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $ramGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    $ramStatus = if ($ramGB -ge $Configuration.MinimumRamGB) { 'PASS' } else { 'WARN' }
    Add-HealthResult 'Hardware' 'Total RAM' $ramStatus "$($Configuration.MinimumRamGB) GB or more" "$ramGB GB" $computer.Model

    $processors = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
    $cpuNames = ($processors.Name | ForEach-Object { $_.Trim() } | Sort-Object -Unique) -join '; '
    $cores = ($processors | Measure-Object NumberOfCores -Sum).Sum
    $logical = ($processors | Measure-Object NumberOfLogicalProcessors -Sum).Sum
    Add-HealthResult 'Hardware' 'CPU' 'INFO' $null $cpuNames "Cores=$cores; LogicalProcessors=$logical"
}
catch { Add-CheckError 'Hardware' 'RAM and CPU' $_ }

try {
    $osDrive = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
    $logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$osDrive'" -ErrorAction Stop
    $sizeGB = [math]::Round($logicalDisk.Size / 1GB, 1)
    $freeGB = [math]::Round($logicalDisk.FreeSpace / 1GB, 1)
    $freePercent = if ($logicalDisk.Size) { [math]::Round(($logicalDisk.FreeSpace / $logicalDisk.Size) * 100, 1) } else { 0 }
    $diskStatus = if ($freeGB -lt $Configuration.CriticalFreeDiskGB -or $freePercent -lt $Configuration.CriticalDiskPercent) {
        'FAIL'
    } elseif ($freeGB -lt $Configuration.MinimumFreeDiskGB -or $freePercent -lt $Configuration.MinimumFreeDiskPercent) {
        'WARN'
    } else { 'PASS' }
    Add-HealthResult 'Storage' 'OS Drive Capacity' 'INFO' $null "$sizeGB GB" "Drive=$osDrive"
    Add-HealthResult 'Storage' 'OS Drive Free Space' $diskStatus "$($Configuration.MinimumFreeDiskGB) GB and $($Configuration.MinimumFreeDiskPercent)% or more" "$freeGB GB ($freePercent%)" "Critical below $($Configuration.CriticalFreeDiskGB) GB or $($Configuration.CriticalDiskPercent)%"
}
catch { Add-CheckError 'Storage' 'OS Drive' $_ }

try {
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop)
        foreach ($disk in $physicalDisks) {
            $health = [string]$disk.HealthStatus
            $status = if ($health -eq 'Healthy') { 'PASS' } elseif ($health) { 'WARN' } else { 'NA' }
            $operational = (@($disk.OperationalStatus) -join ', ')
            $media = if ($disk.MediaType) { $disk.MediaType } else { 'Unspecified' }
            Add-HealthResult 'Storage' "Physical Disk: $($disk.FriendlyName)" $status 'Healthy' $health "Model=$($disk.Model); MediaType=$media; OperationalStatus=$operational; SizeGB=$([math]::Round($disk.Size / 1GB, 1))"

            if (Get-Command Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
                try {
                    $reliability = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
                    $values = @()
                    foreach ($property in @('Temperature', 'Wear', 'PowerOnHours', 'ReadErrorsTotal', 'WriteErrorsTotal')) {
                        if ($null -ne $reliability.$property) { $values += "$property=$($reliability.$property)" }
                    }
                    $actual = if ($values.Count) { $values -join '; ' } else { 'No counters reported' }
                    Add-HealthResult 'Storage' "Disk Reliability: $($disk.FriendlyName)" 'INFO' $null $actual 'SMART/reliability availability varies by controller and drive.'
                }
                catch { Add-HealthResult 'Storage' "Disk Reliability: $($disk.FriendlyName)" 'NA' $null 'Unavailable' $_.Exception.Message }
            }
        }
    } else {
        Add-HealthResult 'Storage' 'Physical Disk Health' 'NA' $null 'Get-PhysicalDisk is unavailable' $null
    }
}
catch { Add-CheckError 'Storage' 'Physical Disk Health' $_ }

# Windows information, uptime, and support expectation
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $installDate = [datetime]$os.InstallDate
    $lastBoot = [datetime]$os.LastBootUpTime
    $uptime = (Get-Date) - $lastBoot
    Add-HealthResult 'Windows' 'Operating System' 'INFO' $null $os.Caption "Version=$($os.Version); Build=$($os.BuildNumber); Architecture=$($os.OSArchitecture)"
    Add-HealthResult 'Windows' 'Installation Date' 'INFO' $null $installDate.ToString('s') $null
    Add-HealthResult 'Windows' 'Last Boot' 'INFO' $null $lastBoot.ToString('s') $null
    $uptimeStatus = if ($uptime.TotalDays -gt $Configuration.MaximumUptimeDays) { 'WARN' } else { 'PASS' }
    Add-HealthResult 'Windows' 'Uptime' $uptimeStatus "$($Configuration.MaximumUptimeDays) days or less" "$([math]::Round($uptime.TotalDays, 1)) days" $null

    if ($Configuration.SupportedWindowsBuilds.Count -gt 0) {
        $supported = $false
        foreach ($supportedBuild in $Configuration.SupportedWindowsBuilds) {
            if ($os.Version -like "$supportedBuild*") { $supported = $true }
        }
        Add-HealthResult 'Windows' 'Expected Windows Version' $(if ($supported) { 'PASS' } else { 'WARN' }) ($Configuration.SupportedWindowsBuilds -join ', ') $os.Version 'Organization-configured expectation; not a Microsoft lifecycle determination.'
    } else {
        $isWorkstation = [int]$os.ProductType -eq 1
        $buildNumber = [int]$os.BuildNumber
        $versionStatus = 'INFO'
        $versionExpected = 'Configure SupportedWindowsBuilds for authoritative enforcement'
        $versionDetail = 'No organization-approved build list is configured.'
        if ($isWorkstation -and $buildNumber -lt 22000) {
            $versionStatus = 'WARN'
            $versionExpected = 'Windows 11 or an explicitly approved Windows 10 servicing channel'
            $versionDetail = 'Standard Windows 10 editions reached end of support; ESU and LTSC exceptions require organization-specific validation.'
        } elseif (-not $isWorkstation -and [version]$os.Version -lt [version]'6.3') {
            $versionStatus = 'WARN'
            $versionExpected = 'A currently supported Windows Server release'
            $versionDetail = 'This legacy server version should be checked against the Microsoft lifecycle.'
        }
        Add-HealthResult 'Windows' 'Expected Windows Version' $versionStatus $versionExpected "$($os.Caption), build $buildNumber" $versionDetail
    }
}
catch { Add-CheckError 'Windows' 'Operating System Information' $_ }

# Pending reboot and reboot history
$pendingReasons = [System.Collections.Generic.List[string]]::new()
foreach ($path in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)) {
    if (Test-Path -LiteralPath $path) { $pendingReasons.Add($path) }
}
$pendingRename = Get-RegistryValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations'
if ($pendingRename.Found -and $pendingRename.Value) { $pendingReasons.Add('PendingFileRenameOperations') }
$updateExeVolatile = Get-RegistryValueSafe 'HKLM:\SOFTWARE\Microsoft\Updates' 'UpdateExeVolatile'
if ($updateExeVolatile.Found -and [int]$updateExeVolatile.Value -ne 0) { $pendingReasons.Add('UpdateExeVolatile') }
if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts') {
    $pendingReasons.Add('Server Manager reboot attempt')
}
if (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain') {
    $pendingReasons.Add('Pending domain join')
}
if (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\AvoidSpnSet') {
    $pendingReasons.Add('Pending domain join SPN update')
}
try {
    $activeComputerName = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name ComputerName -ErrorAction Stop).ComputerName
    $configuredComputerName = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name ComputerName -ErrorAction Stop).ComputerName
    if ($activeComputerName -ne $configuredComputerName) { $pendingReasons.Add('Pending computer rename') }
}
catch {}
try {
    $sccm = Invoke-CimMethod -Namespace 'root\ccm\ClientSDK' -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -ErrorAction Stop
    if ($sccm.RebootPending -or $sccm.IsHardRebootPending) { $pendingReasons.Add('Configuration Manager client') }
}
catch {}
$pendingStatus = if ($pendingReasons.Count) { 'WARN' } else { 'PASS' }
$pendingActual = if ($pendingReasons.Count) { 'Pending reboot detected' } else { 'No common pending-reboot indicators' }
Add-HealthResult 'Reboot' 'Pending Reboot' $pendingStatus 'No pending reboot' $pendingActual ($pendingReasons -join '; ')

try {
    $rebootEvents = @(Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Id = 41, 1074, 6005, 6006, 6008
        StartTime = (Get-Date).AddDays(-$Configuration.EventLookbackDays)
    } -ErrorAction Stop | Select-Object -First $Configuration.RecentEventCount)
    $unexpected = @($rebootEvents | Where-Object { $_.Id -in 41, 6008 })
    Add-HealthResult 'Reboot' 'Recent Restart and Shutdown Events' $(if ($unexpected.Count) { 'WARN' } else { 'INFO' }) 'No unexpected shutdowns' "$($rebootEvents.Count) relevant events; $($unexpected.Count) unexpected" 'Use -VerboseStandalone for event rows.'
    if ($VerboseStandalone) {
        $eventMeaning = @{ 41 = 'System rebooted without a clean shutdown'; 1074 = 'A process or user initiated restart/shutdown'; 6005 = 'Event Log service started (boot indicator)'; 6006 = 'Event Log service stopped (clean shutdown indicator)'; 6008 = 'Previous shutdown was unexpected' }
        foreach ($event in $rebootEvents) {
            Add-HealthResult 'Reboot Event' "Event $($event.Id)" $(if ($event.Id -in 41, 6008) { 'WARN' } else { 'INFO' }) $null $event.TimeCreated.ToString('s') "Provider=$($event.ProviderName); Meaning=$($eventMeaning[[int]$event.Id]); Message=$(ConvertTo-ShortText $event.Message)"
        }
    }
}
catch { Add-CheckError 'Reboot' 'Recent Restart and Shutdown Events' $_ }

# Targeted high-value event readback
try {
    $targetProviders = 'disk|ntfs|storport|stornvme|volmgr|kernel-power|service control manager|application error|windows error reporting|group.?policy|dns|time-service|user profiles service'
    $candidateEvents = @()
    foreach ($logName in @('System', 'Application')) {
        try {
            $candidateEvents += Get-WinEvent -FilterHashtable @{
                LogName = $logName
                Level = 1, 2, 3
                StartTime = (Get-Date).AddDays(-$Configuration.EventLookbackDays)
            } -MaxEvents 150 -ErrorAction Stop
        }
        catch {}
    }
    $relevantEvents = @($candidateEvents |
        Where-Object { $_.ProviderName -match $targetProviders -or $_.Id -in 41, 55, 1000, 1001, 1014, 1129, 1500, 1509, 1511, 1530, 7000, 7001, 7009, 7011, 7023, 7024, 7031, 7034 } |
        Sort-Object TimeCreated -Descending |
        Select-Object -First $Configuration.RecentEventCount)
    $criticalCount = @($relevantEvents | Where-Object { $_.Level -in 1, 2 }).Count
    Add-HealthResult 'Events' 'Recent High-Value Errors' $(if ($criticalCount) { 'WARN' } else { 'INFO' }) 'No recent critical/error signals' "$($relevantEvents.Count) relevant events; $criticalCount critical/error" "Last $($Configuration.EventLookbackDays) days; use -VerboseStandalone for event rows."
    if ($VerboseStandalone) {
        foreach ($event in $relevantEvents) {
            $level = if ($event.LevelDisplayName) { $event.LevelDisplayName } else { [string]$event.Level }
            Add-HealthResult 'Event' "$($event.LogName) Event $($event.Id)" $(if ($event.Level -in 1, 2) { 'WARN' } else { 'INFO' }) $null $event.TimeCreated.ToString('s') "Provider=$($event.ProviderName); Level=$level; Message=$(ConvertTo-ShortText $event.Message)"
        }
    }
}
catch { Add-CheckError 'Events' 'Recent High-Value Errors' $_ }

# BitLocker, TPM, and Secure Boot
try {
    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        $bitLocker = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $protected = [string]$bitLocker.ProtectionStatus -eq 'On'
        Add-HealthResult 'Security' 'BitLocker OS Drive' $(if ($protected) { 'PASS' } else { 'WARN' }) 'Protection On' ([string]$bitLocker.ProtectionStatus) "VolumeStatus=$($bitLocker.VolumeStatus); Encryption=$($bitLocker.EncryptionMethod); Percent=$($bitLocker.EncryptionPercentage)"
    } else { Add-HealthResult 'Security' 'BitLocker OS Drive' 'NA' $null 'Cmdlet unavailable' $null }
}
catch { Add-CheckError 'Security' 'BitLocker OS Drive' $_ }

try {
    if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
        $tpm = Get-Tpm -ErrorAction Stop
        $tpmStatus = if (-not $tpm.TpmPresent) { 'WARN' } elseif ($tpm.TpmReady) { 'PASS' } else { 'WARN' }
        Add-HealthResult 'Security' 'TPM' $tpmStatus 'Present and ready' "Present=$($tpm.TpmPresent); Ready=$($tpm.TpmReady)" "Enabled=$($tpm.TpmEnabled); Activated=$($tpm.TpmActivated)"
    } else { Add-HealthResult 'Security' 'TPM' 'NA' $null 'Cmdlet unavailable' $null }
}
catch { Add-CheckError 'Security' 'TPM' $_ }

try {
    if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
        $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
        Add-HealthResult 'Security' 'Secure Boot' $(if ($secureBoot) { 'PASS' } else { 'WARN' }) 'Enabled' $secureBoot $null
    } else { Add-HealthResult 'Security' 'Secure Boot' 'NA' $null 'Cmdlet unavailable' $null }
}
catch { Add-HealthResult 'Security' 'Secure Boot' 'NA' $null 'Unavailable or unsupported' $_.Exception.Message }

# Security products and Microsoft Defender
$securityProducts = @()
try {
    $securityProducts = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntivirusProduct -ErrorAction Stop)
    if ($securityProducts.Count) {
        $names = ($securityProducts.displayName | Sort-Object -Unique) -join '; '
        Add-HealthResult 'Security Software' 'Registered Antivirus Providers' 'INFO' $null $names 'Registration and active-state encoding are vendor/Windows-version dependent.'
    } else { Add-HealthResult 'Security Software' 'Registered Antivirus Providers' 'WARN' 'At least one provider' 'None reported' $null }
}
catch { Add-HealthResult 'Security Software' 'Registered Antivirus Providers' 'NA' $null 'SecurityCenter2 unavailable' $_.Exception.Message }

$installedSoftware = @(Get-InstalledSoftware)
$securityPatterns = [ordered]@{
    'Microsoft Defender' = 'Microsoft Defender|Windows Defender'
    'Sophos'             = 'Sophos'
    'CrowdStrike'        = 'CrowdStrike|Falcon Sensor'
    'SentinelOne'        = 'SentinelOne|Sentinel Agent'
    'Huntress'           = 'Huntress'
    'Malwarebytes'       = 'Malwarebytes'
}
$detectedSecurity = foreach ($vendor in $securityPatterns.Keys) {
    $registered = @($securityProducts | Where-Object { $_.displayName -match $securityPatterns[$vendor] })
    $installed = @($installedSoftware | Where-Object { $_.Name -match $securityPatterns[$vendor] })
    $serviceFound = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $securityPatterns[$vendor] -or $_.DisplayName -match $securityPatterns[$vendor] })
    if ($registered.Count -or $installed.Count -or $serviceFound.Count) { $vendor }
}
Add-HealthResult 'Security Software' 'Common Security Products' 'INFO' $null $(if ($detectedSecurity) { $detectedSecurity -join '; ' } else { 'None detected by lightweight checks' }) 'Detection uses Security Center, installed-software records, and service names.'

$thirdPartyAv = @($securityProducts | Where-Object { $_.displayName -notmatch 'Microsoft Defender|Windows Defender' }).Count -gt 0
try {
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        $defender = Get-MpComputerStatus -ErrorAction Stop
        $defenderActive = [bool]$defender.AntivirusEnabled
        $defenderStatus = if ($defenderActive) { 'PASS' } elseif ($thirdPartyAv) { 'INFO' } else { 'WARN' }
        $expected = if ($thirdPartyAv) { 'Enabled, or passive when third-party AV is active' } else { 'Enabled' }
        Add-HealthResult 'Microsoft Defender' 'Antivirus' $defenderStatus $expected $defender.AntivirusEnabled "AMServiceEnabled=$($defender.AMServiceEnabled); ThirdPartyAV=$thirdPartyAv"
        foreach ($feature in @(
            @{ Name = 'Real-Time Protection'; Property = 'RealTimeProtectionEnabled' }
            @{ Name = 'Behavior Monitoring'; Property = 'BehaviorMonitorEnabled' }
            @{ Name = 'Cloud Protection'; Property = 'MAPSReporting' }
        )) {
            $value = $defender.($feature.Property)
            $status = if ($defenderActive -and $value) { 'PASS' } elseif ($thirdPartyAv) { 'INFO' } else { 'WARN' }
            Add-HealthResult 'Microsoft Defender' $feature.Name $status 'Enabled when Defender is active' $value $null
        }
        $signatureAge = $defender.AntivirusSignatureAge
        $signatureStatus = if (-not $defenderActive -and $thirdPartyAv) { 'INFO' } elseif ($null -eq $signatureAge) { 'NA' } elseif ($signatureAge -le 3) { 'PASS' } else { 'WARN' }
        Add-HealthResult 'Microsoft Defender' 'Signature Age' $signatureStatus '3 days or less when Defender is active' $(if ($null -eq $signatureAge) { 'Unknown' } else { "$signatureAge days" }) "LastUpdated=$($defender.AntivirusSignatureLastUpdated)"
        $defenderService = Get-Service WinDefend -ErrorAction SilentlyContinue
        Add-HealthResult 'Microsoft Defender' 'Service' $(if ($defenderService.Status -eq 'Running') { 'PASS' } elseif ($thirdPartyAv) { 'INFO' } else { 'WARN' }) 'Running when Defender is active' $defenderService.Status $null
    } else { Add-HealthResult 'Microsoft Defender' 'Health' 'NA' $null 'Get-MpComputerStatus unavailable' $null }
}
catch { Add-CheckError 'Microsoft Defender' 'Health' $_ }

# Firewall profiles
try {
    if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
        foreach ($profile in Get-NetFirewallProfile -ErrorAction Stop) {
            Add-HealthResult 'Firewall' "$($profile.Name) Profile" $(if ($profile.Enabled) { 'PASS' } else { 'WARN' }) 'Enabled' $profile.Enabled "DefaultInbound=$($profile.DefaultInboundAction); DefaultOutbound=$($profile.DefaultOutboundAction)"
        }
    } else { Add-HealthResult 'Firewall' 'Profiles' 'NA' $null 'Cmdlet unavailable' $null }
}
catch { Add-CheckError 'Firewall' 'Profiles' $_ }

# Local users and local administrators
try {
    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        $localUsers = @(Get-LocalUser -ErrorAction Stop)
        $guest = $localUsers | Where-Object { $_.SID.Value -match '-501$' } | Select-Object -First 1
        Add-HealthResult 'Accounts' 'Guest Account' $(if ($guest.Enabled) { 'WARN' } else { 'PASS' }) 'Disabled' $guest.Enabled "Name=$($guest.Name)"
        Add-HealthResult 'Accounts' 'Local User Summary' 'INFO' $null "$($localUsers.Count) accounts; $(@($localUsers | Where-Object Enabled).Count) enabled" 'Use -VerboseStandalone for individual accounts.'
        if ($VerboseStandalone) {
            foreach ($user in $localUsers) {
                Add-HealthResult 'Local User' $user.Name 'INFO' $null $(if ($user.Enabled) { 'Enabled' } else { 'Disabled' }) "LastLogon=$($user.LastLogon); PasswordNeverExpires=$($user.PasswordNeverExpires); SID=$($user.SID)"
            }
        }
    } else { Add-HealthResult 'Accounts' 'Local Users' 'NA' $null 'LocalAccounts module unavailable' $null }

    if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
        $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop)
        $unexpectedAdmins = @($admins | Where-Object {
            $memberName = $_.Name
            -not ($Configuration.ApprovedLocalAdmins | Where-Object { $memberName -eq $_ -or $memberName -like "*\$_" })
        })
        Add-HealthResult 'Accounts' 'Local Administrators' $(if ($unexpectedAdmins.Count) { 'WARN' } else { 'PASS' }) ($Configuration.ApprovedLocalAdmins -join '; ') ($admins.Name -join '; ') $(if ($unexpectedAdmins.Count) { "Unexpected=$($unexpectedAdmins.Name -join '; ')" } else { 'No unexpected administrators' })
    } else { Add-HealthResult 'Accounts' 'Local Administrators' 'NA' $null 'LocalAccounts module unavailable' $null }
}
catch { Add-CheckError 'Accounts' 'Local Accounts' $_ }

# Important registry-backed Windows settings
$settingChecks = @(
    @{ Check = 'UAC'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'EnableLUA'; Good = 1; Expected = 'Enabled (1)'; Explain = 'UAC reduces the impact of administrative actions.' }
    @{ Check = 'Fast Startup'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Good = 0; Expected = 'Disabled (0) for full shutdown behavior'; Explain = 'Enabled Fast Startup can preserve kernel state across shutdown.' }
    @{ Check = 'LLMNR'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableMulticast'; Good = 0; Expected = 'Disabled by policy (0)'; Explain = 'Disabling LLMNR reduces name-resolution spoofing exposure; missing means not explicitly configured.' }
    @{ Check = 'Screen Inactivity Timeout'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'InactivityTimeoutSecs'; Good = $null; Expected = 'Organization-defined nonzero timeout'; Explain = 'Machine inactivity limit before lock; missing may be controlled elsewhere.' }
    @{ Check = 'Telemetry Policy'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Good = $null; Expected = 'Organization policy'; Explain = 'Diagnostic data policy; edition and policy source affect interpretation.' }
)
foreach ($setting in $settingChecks) {
    $reg = Get-RegistryValueSafe $setting.Path $setting.Name
    if ($reg.Error) {
        Add-RegistryResult $setting.Check $setting.Path $setting.Name 'ERROR' $setting.Expected 'Unreadable' $reg.Error
    } elseif (-not $reg.Found) {
        Add-RegistryResult $setting.Check $setting.Path $setting.Name 'INFO' $setting.Expected 'Not configured' $setting.Explain
    } else {
        $status = 'INFO'
        if ($null -ne $setting.Good) { $status = if ([int]$reg.Value -eq [int]$setting.Good) { 'PASS' } else { 'WARN' } }
        if ($setting.Check -eq 'Screen Inactivity Timeout') { $status = if ([int]$reg.Value -gt 0) { 'PASS' } else { 'WARN' } }
        Add-RegistryResult $setting.Check $setting.Path $setting.Name $status $setting.Expected $reg.Value $setting.Explain
    }
}

try {
    $smb1 = Get-SmbServerConfiguration -ErrorAction Stop
    Add-HealthResult 'Windows Settings' 'SMBv1 Server' $(if ($smb1.EnableSMB1Protocol) { 'WARN' } else { 'PASS' }) 'Disabled' $smb1.EnableSMB1Protocol 'Server-side SMBv1 protocol state.'
}
catch { Add-HealthResult 'Windows Settings' 'SMBv1 Server' 'NA' $null 'Unavailable' $_.Exception.Message }
try {
    if (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
        $smbFeature = Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction Stop
        Add-HealthResult 'Windows Settings' 'SMBv1 Optional Feature' $(if ($smbFeature.State -eq 'Enabled') { 'WARN' } else { 'PASS' }) 'Disabled' $smbFeature.State 'Covers installed SMBv1 client/server components where Windows exposes the optional feature.'
    }
}
catch { Add-HealthResult 'Windows Settings' 'SMBv1 Optional Feature' 'NA' $null 'Unavailable' $_.Exception.Message }

$rdp = Get-RegistryValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'
if ($rdp.Found) {
    $rdpEnabled = [int]$rdp.Value -eq 0
    Add-RegistryResult 'Remote Desktop' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 'INFO' 'Organization policy' $(if ($rdpEnabled) { 'Enabled' } else { 'Disabled' }) 'RDP exposure is informational because business requirements differ.'
    if ($rdpEnabled) {
        $nla = Get-RegistryValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication'
        Add-RegistryResult 'RDP Network Level Authentication' 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication' $(if ($nla.Value -eq 1) { 'PASS' } else { 'WARN' }) 'Enabled (1)' $nla.Value 'NLA should normally be enabled when RDP is enabled.'
    }
}

# Power and Fast Startup context
try {
    $hibernate = Get-RegistryValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
    Add-HealthResult 'Power' 'Hibernation' 'INFO' $null $(if ($hibernate.Value -eq 1) { 'Enabled' } else { 'Disabled or unavailable' }) "RegistryPath=HKLM:\SYSTEM\CurrentControlSet\Control\Power; ValueName=HibernateEnabled"
    $powerPlanText = (& powercfg.exe /GetActiveScheme 2>&1 | Select-Object -First 1) -as [string]
    Add-HealthResult 'Power' 'Active Power Plan' 'INFO' $null (ConvertTo-ShortText $powerPlanText) $null
}
catch { Add-CheckError 'Power' 'Power Configuration' $_ }

# Required shortcuts, files, software, and services
foreach ($shortcut in $Configuration.RequiredShortcuts) {
    try {
        $exists = Test-Path -LiteralPath $shortcut.Path -PathType Leaf
        $target = $null
        $targetExists = $false
        if ($exists) {
            $shell = New-Object -ComObject WScript.Shell
            $target = $shell.CreateShortcut($shortcut.Path).TargetPath
            if ($target) { $targetExists = Test-Path -LiteralPath $target }
        }
        $status = if (-not $exists) { 'FAIL' } elseif (-not $target -or -not $targetExists) { 'WARN' } else { 'PASS' }
        Add-HealthResult 'Required Items' "Shortcut: $($shortcut.Name)" $status 'Shortcut and target exist' "ShortcutExists=$exists; TargetExists=$targetExists" "Path=$($shortcut.Path); Target=$target"
    }
    catch { Add-CheckError 'Required Items' "Shortcut: $($shortcut.Name)" $_ }
}
foreach ($requiredPath in $Configuration.RequiredPaths) {
    try {
        $pathType = if ($requiredPath.Type) { $requiredPath.Type } else { 'Any' }
        $pathsToCheck = @($requiredPath.Path)
        if ($requiredPath.Path -like '*{UserProfile}*') {
            $pathsToCheck = @(Get-UserProfiles | ForEach-Object { $requiredPath.Path.Replace('{UserProfile}', $_) })
        }
        if (-not $pathsToCheck.Count) {
            Add-HealthResult 'Required Items' "Path: $($requiredPath.Name)" 'NA' 'Exists' 'No accessible user profiles' $requiredPath.Path
            continue
        }
        foreach ($expandedPath in $pathsToCheck) {
            $exists = Test-Path -LiteralPath $expandedPath -PathType $pathType
            $profileLabel = if ($requiredPath.Path -like '*{UserProfile}*') { " ($(Split-Path (Split-Path $expandedPath -Parent) -Parent | Split-Path -Leaf))" } else { '' }
            Add-HealthResult 'Required Items' "Path: $($requiredPath.Name)$profileLabel" $(if ($exists) { 'PASS' } else { 'FAIL' }) 'Exists' $exists $expandedPath
        }
    }
    catch { Add-CheckError 'Required Items' "Path: $($requiredPath.Name)" $_ }
}
foreach ($requiredSoftware in $Configuration.RequiredSoftware) {
    try {
        $matches = @()
        foreach ($pattern in @($requiredSoftware.Match)) {
            if ([string]::IsNullOrWhiteSpace([string]$pattern)) { continue }
            $matches += @($installedSoftware | Where-Object { $_.Name -like $pattern })
        }
        $matches = @($matches | Sort-Object Name, Version -Unique)
        $pathMatches = @()
        foreach ($candidatePath in @($requiredSoftware.Paths)) {
            if ([string]::IsNullOrWhiteSpace([string]$candidatePath)) { continue }
            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) { $pathMatches += $candidatePath }
        }
        $appxMatches = @()
        if ($requiredSoftware.AppxName -and (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
            $appxMatches = @(Get-AppxPackage -AllUsers -Name $requiredSoftware.AppxName -ErrorAction SilentlyContinue)
        }
        $installed = $matches.Count -gt 0 -or $pathMatches.Count -gt 0 -or $appxMatches.Count -gt 0
        $version = ($matches.Version | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1)
        if (-not $version -and $pathMatches.Count) {
            $version = (Get-Item -LiteralPath $pathMatches[0] -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
        }
        if (-not $version -and $appxMatches.Count) { $version = [string]$appxMatches[0].Version }
        $versionTooLow = $false
        if ($installed -and $requiredSoftware.MinimumVersion -and $version) {
            try { $versionTooLow = [version]$version -lt [version]$requiredSoftware.MinimumVersion } catch {}
        }
        $status = if (-not $installed) { 'FAIL' } elseif ($versionTooLow) { 'WARN' } else { 'PASS' }
        $detectionDetails = @($matches.Name) + $pathMatches + @($appxMatches.Name)
        Add-HealthResult 'Required Software' $requiredSoftware.Name $status "Installed$(if ($requiredSoftware.MinimumVersion) { "; version $($requiredSoftware.MinimumVersion)+" })" $(if ($installed) { "Installed; version $(if ($version) { $version } else { 'unknown' })" } else { 'Not installed' }) ($detectionDetails -join '; ')
    }
    catch { Add-CheckError 'Required Software' $requiredSoftware.Name $_ }
}
foreach ($requiredService in $Configuration.RequiredServices) {
    try {
        $service = Get-CimInstance Win32_Service -Filter "Name='$($requiredService.Name.Replace("'", "''"))'" -ErrorAction Stop
        if (-not $service) {
            Add-HealthResult 'Required Services' $requiredService.Name 'FAIL' 'Exists' 'Not found' $null
            continue
        }
        $stateGood = -not $requiredService.RequiredState -or $service.State -eq $requiredService.RequiredState
        $startGood = -not $requiredService.RequiredStartType -or $service.StartMode -eq $requiredService.RequiredStartType -or ($requiredService.RequiredStartType -eq 'Automatic' -and $service.StartMode -eq 'Auto')
        Add-HealthResult 'Required Services' $requiredService.Name $(if ($stateGood -and $startGood) { 'PASS' } else { 'WARN' }) "State=$($requiredService.RequiredState); Start=$($requiredService.RequiredStartType)" "State=$($service.State); Start=$($service.StartMode)" $service.DisplayName
    }
    catch { Add-CheckError 'Required Services' $requiredService.Name $_ }
}

# Network basics and Windows Time
try {
    if (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
        $activeAdapters = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.NetAdapter.Status -eq 'Up' })
        Add-HealthResult 'Network' 'Active Adapters' $(if ($activeAdapters.Count) { 'PASS' } else { 'WARN' }) 'At least one active adapter' $activeAdapters.Count 'Use -VerboseStandalone for adapter details.'
        if ($VerboseStandalone) {
            foreach ($adapter in $activeAdapters) {
                $addresses = @($adapter.IPv4Address.IPAddress) + @($adapter.IPv6Address.IPAddress)
                Add-HealthResult 'Network Adapter' $adapter.InterfaceAlias 'INFO' $null ($addresses -join ', ') "Gateway=$($adapter.IPv4DefaultGateway.NextHop); DNS=$($adapter.DNSServer.ServerAddresses -join ', '); Profile=$($adapter.NetProfile.Name); Category=$($adapter.NetProfile.NetworkCategory)"
            }
        }
    } else { Add-HealthResult 'Network' 'Active Adapters' 'NA' $null 'Networking cmdlets unavailable' $null }
}
catch { Add-CheckError 'Network' 'Active Adapters' $_ }

try {
    $dnsResult = Resolve-DnsName -Name $Configuration.DnsTestName -DnsOnly -QuickTimeout -ErrorAction Stop | Select-Object -First 1
    Add-HealthResult 'Network' 'DNS Resolution' 'PASS' "Resolve $($Configuration.DnsTestName)" $dnsResult.IPAddress "Type=$($dnsResult.Type)"
}
catch { Add-HealthResult 'Network' 'DNS Resolution' 'WARN' "Resolve $($Configuration.DnsTestName)" 'Failed' $_.Exception.Message }

try {
    $w32time = Get-CimInstance Win32_Service -Filter "Name='W32Time'" -ErrorAction Stop
    $source = ConvertTo-ShortText ((& w32tm.exe /query /source 2>&1 | Select-Object -First 1) -as [string])
    Add-HealthResult 'Network' 'Windows Time' $(if ($w32time.State -eq 'Running') { 'PASS' } else { 'WARN' }) 'Service running' $w32time.State "StartMode=$($w32time.StartMode); Source=$source"
}
catch { Add-CheckError 'Network' 'Windows Time' $_ }

# PowerShell, Python, and developer tooling
Add-HealthResult 'Developer Tools' 'Current PowerShell' 'INFO' $null "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)" $PSHOME
try {
    $windowsPowerShell = Get-RegistryValueSafe 'HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine' 'PowerShellVersion'
    Add-HealthResult 'Developer Tools' 'Windows PowerShell' $(if ($windowsPowerShell.Found) { 'INFO' } else { 'NA' }) $null $(if ($windowsPowerShell.Found) { $windowsPowerShell.Value } else { 'Not detected' }) $null
} catch { Add-CheckError 'Developer Tools' 'Windows PowerShell' $_ }

$pwsh = Get-CommandDetail @('pwsh.exe', 'pwsh') @('-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
Add-HealthResult 'Developer Tools' 'PowerShell 7' $(if ($pwsh.Found) { 'INFO' } else { 'NA' }) $null $(if ($pwsh.Found) { $pwsh.Version } else { 'Not installed' }) $pwsh.Path

$modules = @(Get-Module -ListAvailable -ErrorAction SilentlyContinue |
    Sort-Object Name, Version -Descending |
    Group-Object Name |
    ForEach-Object { $_.Group | Select-Object -First 1 })
Add-HealthResult 'Developer Tools' 'PowerShell Modules' 'INFO' $null "$($modules.Count) unique modules" 'Use -VerboseStandalone for name and highest available version.'
if ($VerboseStandalone) {
    foreach ($module in $modules) { Add-HealthResult 'PowerShell Module' $module.Name 'INFO' $null $module.Version $null }
}

$python = Get-CommandDetail @('python.exe', 'python', 'py.exe', 'py') @('--version')
Add-HealthResult 'Developer Tools' 'Python' $(if ($python.Found) { 'INFO' } else { 'NA' }) $null $(if ($python.Found) { $python.Version } else { 'Not installed' }) $python.Path
$pip = Get-CommandDetail @('pip.exe', 'pip', 'pip3.exe', 'pip3') @('--version')
Add-HealthResult 'Developer Tools' 'pip' $(if ($pip.Found) { 'INFO' } else { 'NA' }) $null $(if ($pip.Found) { $pip.Version } else { 'Not available' }) $pip.Path
$git = Get-CommandDetail @('git.exe', 'git') @('--version')
Add-HealthResult 'Developer Tools' 'Git' $(if ($git.Found) { 'INFO' } else { 'NA' }) $null $(if ($git.Found) { $git.Version } else { 'Not installed' }) $git.Path

$code = Get-CommandDetail @('code.cmd', 'code.exe', 'code') @('--version')
if (-not $code.Found) {
    $codeInstall = $installedSoftware | Where-Object { $_.Name -match '^Microsoft Visual Studio Code' } | Select-Object -First 1
    if ($codeInstall) { $code = [PSCustomObject]@{ Found = $true; Path = 'Detected in installed software'; Version = $codeInstall.Version } }
}
Add-HealthResult 'Developer Tools' 'Visual Studio Code' $(if ($code.Found) { 'INFO' } else { 'NA' }) $null $(if ($code.Found) { $code.Version } else { 'Not installed' }) $code.Path

# AI tooling, including VS Code-family extensions across local profiles
$aiPatterns = [ordered]@{
    'GitHub Copilot'      = 'github\.copilot-\d'
    'GitHub Copilot Chat' = 'github\.copilot-chat-'
    'Cline'               = 'saoudrizwan\.claude-dev|cline'
    'Roo Code'            = 'rooveterinaryinc\.roo-cline|roo-cline'
    'Continue'            = 'continue\.continue'
}
$aiFindings = [System.Collections.Generic.List[string]]::new()
$extensionCount = 0
foreach ($profilePath in Get-UserProfiles) {
    foreach ($extensionRoot in @(
        (Join-Path $profilePath '.vscode\extensions')
        (Join-Path $profilePath '.cursor\extensions')
        (Join-Path $profilePath '.windsurf\extensions')
    )) {
        if (-not (Test-Path -LiteralPath $extensionRoot -PathType Container)) { continue }
        $extensions = @(Get-ChildItem -LiteralPath $extensionRoot -Directory -ErrorAction SilentlyContinue)
        $extensionCount += $extensions.Count
        foreach ($tool in $aiPatterns.Keys) {
            if ($extensions.Name -match $aiPatterns[$tool]) { $aiFindings.Add("$tool ($extensionRoot)") }
        }
    }
}
$appPatterns = [ordered]@{
    'Cursor' = '^Cursor$|Cursor User'
    'Windsurf' = 'Windsurf'
    'Claude' = '^Claude$|Claude Desktop'
    'ChatGPT' = '^ChatGPT$|OpenAI ChatGPT'
    'Ollama' = 'Ollama'
}
foreach ($tool in $appPatterns.Keys) {
    if ($installedSoftware.Name -match $appPatterns[$tool] -or (Get-Command ($tool.ToLower() + '.exe') -ErrorAction SilentlyContinue)) { $aiFindings.Add($tool) }
}
$uniqueAiFindings = @($aiFindings | Sort-Object -Unique)
Add-HealthResult 'AI Tools' 'Detected Tools' 'INFO' $null $(if ($uniqueAiFindings.Count) { $uniqueAiFindings -join '; ' } else { 'None detected by lightweight checks' }) "VS Code-family extension folders inspected; total extensions=$extensionCount"

# Credential-like filenames and lightweight hygiene
$suspiciousNames = @('password.xlsx', 'passwords.xlsx', 'password.txt', 'passwords.txt', 'credentials.xlsx', 'credentials.txt', 'secrets.txt')
$suspiciousFiles = [System.Collections.Generic.List[string]]::new()
$desktopFileCount = 0
$downloadsGB = 0.0
foreach ($profilePath in Get-UserProfiles) {
    foreach ($folderName in @('Desktop', 'Documents', 'Downloads')) {
        $folder = Join-Path $profilePath $folderName
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        foreach ($name in $suspiciousNames) {
            Get-ChildItem -LiteralPath $folder -Filter $name -File -ErrorAction SilentlyContinue | ForEach-Object { $suspiciousFiles.Add($_.FullName) }
        }
        if ($folderName -eq 'Desktop') { $desktopFileCount += @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue).Count }
        if ($folderName -eq 'Downloads') {
            $folderSize = Get-FolderSizeGB $folder
            if ($null -ne $folderSize) { $downloadsGB += $folderSize }
        }
    }
}
$credentialStatus = if ($suspiciousFiles.Count) { 'WARN' } else { 'PASS' }
Add-HealthResult 'Hygiene' 'Credential-Like Filenames' $credentialStatus 'None in Desktop, Documents, or Downloads' $suspiciousFiles.Count $(if ($VerboseStandalone -and $suspiciousFiles.Count) { $suspiciousFiles -join '; ' } else { 'File contents were not read; use -VerboseStandalone for paths.' })
Add-HealthResult 'Hygiene' 'Desktop File Count' $(if ($desktopFileCount -gt $Configuration.MaximumDesktopFiles) { 'WARN' } else { 'INFO' }) "$($Configuration.MaximumDesktopFiles) or fewer" $desktopFileCount 'Top-level files across accessible user Desktop folders.'
Add-HealthResult 'Hygiene' 'Downloads Size' $(if ($downloadsGB -gt $Configuration.MaximumDownloadsGB) { 'WARN' } else { 'INFO' }) "$($Configuration.MaximumDownloadsGB) GB or less" "$([math]::Round($downloadsGB, 2)) GB" 'Accessible user Downloads folders; file contents were not read.'

$tempPath = Join-Path $env:SystemRoot 'Temp'
$tempGB = Get-FolderSizeGB $tempPath
Add-HealthResult 'Hygiene' 'Windows TEMP Size' 'INFO' $null $(if ($null -ne $tempGB) { "$tempGB GB" } else { 'Unavailable' }) $tempPath

$memoryDump = Join-Path $env:SystemRoot 'MEMORY.DMP'
if (Test-Path -LiteralPath $memoryDump -PathType Leaf) {
    $dumpItem = Get-Item -LiteralPath $memoryDump -ErrorAction SilentlyContinue
    Add-HealthResult 'Hygiene' 'MEMORY.DMP' 'WARN' 'Not present' "$([math]::Round($dumpItem.Length / 1GB, 2)) GB" "LastWrite=$($dumpItem.LastWriteTime.ToString('s')); Path=$memoryDump"
} else { Add-HealthResult 'Hygiene' 'MEMORY.DMP' 'INFO' $null 'Not present' $memoryDump }

$miniDumpPath = Join-Path $env:SystemRoot 'Minidump'
$miniDumps = @(Get-ChildItem -LiteralPath $miniDumpPath -Filter '*.dmp' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-$Configuration.EventLookbackDays) } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5)
Add-HealthResult 'Hygiene' 'Recent Minidumps' $(if ($miniDumps.Count) { 'WARN' } else { 'INFO' }) 'None recently' $miniDumps.Count $(if ($miniDumps.Count) { ($miniDumps | ForEach-Object { "$($_.Name) $($_.LastWriteTime.ToString('s'))" }) -join '; ' } else { $miniDumpPath })

# Professional observations
if ($uptime -and $uptime.TotalDays -gt $Configuration.MaximumUptimeDays) {
    Add-HealthResult 'Observation' 'Long Uptime' 'INFO' $null "$([math]::Round($uptime.TotalDays, 1)) days" 'A true restart may clear stale state and complete servicing.'
}
if ($downloadsGB -gt $Configuration.MaximumDownloadsGB) {
    Add-HealthResult 'Observation' 'Large Downloads Folder' 'INFO' $null "$([math]::Round($downloadsGB, 2)) GB" 'Review rather than deleting automatically.'
}
if ($desktopFileCount -gt $Configuration.MaximumDesktopFiles) {
    Add-HealthResult 'Observation' 'Cluttered Desktop' 'INFO' $null "$desktopFileCount files" 'Large redirected or synchronized desktops can affect sign-in performance.'
}
$fastStartup = Get-RegistryValueSafe 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled'
if ($fastStartup.Value -eq 1 -and $uptime -and $uptime.TotalDays -gt 7) {
    Add-HealthResult 'Observation' 'Fast Startup and Uptime' 'INFO' $null 'Fast Startup enabled with uptime over 7 days' 'Shutdown may not have performed a full kernel restart; use Restart for a true reboot.'
}
if ($env:COMPUTERNAME -notmatch $Configuration.ExpectedHostnamePattern) {
    Add-HealthResult 'Observation' 'Hostname Pattern' 'WARN' $Configuration.ExpectedHostnamePattern $env:COMPUTERNAME 'Hostname does not match the configured pattern.'
} else {
    Add-HealthResult 'Observation' 'Hostname Pattern' 'PASS' $Configuration.ExpectedHostnamePattern $env:COMPUTERNAME $null
}
if ($extensionCount -gt $Configuration.MaximumVsCodeExtensions) {
    Add-HealthResult 'Observation' 'VS Code Extension Count' 'INFO' "$($Configuration.MaximumVsCodeExtensions) or fewer" $extensionCount 'A very large extension set can affect editor startup and troubleshooting complexity.'
}

# Summary rows first, followed by details. INFO and NA do not degrade health.
$passCount = @($script:Results | Where-Object Status -eq 'PASS').Count
$warningCount = @($script:Results | Where-Object Status -eq 'WARN').Count
$failureCount = @($script:Results | Where-Object Status -eq 'FAIL').Count
$errorCount = @($script:Results | Where-Object Status -eq 'ERROR').Count
$infoCount = @($script:Results | Where-Object Status -eq 'INFO').Count
$naCount = @($script:Results | Where-Object Status -eq 'NA').Count
$totalCount = $script:Results.Count
$overallHealth = if ($failureCount -gt 0 -or $errorCount -gt 0) { 'FAIL' } elseif ($warningCount -gt 0) { 'WARN' } else { 'PASS' }
$selectedOutputMode = if ($ConsoleOutput) { 'Console' } elseif ($ObjectOutput) { 'Objects' } else { 'ConnectTable' }
$summary = @(
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Overall Health'; Status = $overallHealth; Expected = 'PASS'; Actual = $overallHealth; Details = "Computer=$env:COMPUTERNAME; DetailMode=$(if ($VerboseStandalone) { 'VerboseStandalone' } else { 'Concise' }); ResultFilter=$(if ($IssuesOnly) { 'IssuesOnly' } else { 'All' }); OutputMode=$selectedOutputMode" }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Total Checks'; Status = 'INFO'; Expected = $null; Actual = $totalCount; Details = $null }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Passed'; Status = 'INFO'; Expected = $null; Actual = $passCount; Details = $null }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Warnings'; Status = 'INFO'; Expected = $null; Actual = $warningCount; Details = $null }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Failures'; Status = 'INFO'; Expected = $null; Actual = $failureCount; Details = $null }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Errors'; Status = 'INFO'; Expected = $null; Actual = $errorCount; Details = $null }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Informational'; Status = 'INFO'; Expected = $null; Actual = $infoCount; Details = $null }
    [PSCustomObject][ordered]@{ Category = 'Summary'; Check = 'Not Applicable'; Status = 'INFO'; Expected = $null; Actual = $naCount; Details = $null }
)

$categorySummary = foreach ($group in $script:Results | Group-Object Category) {
    $categoryPass = @($group.Group | Where-Object Status -eq 'PASS').Count
    $categoryWarn = @($group.Group | Where-Object Status -eq 'WARN').Count
    $categoryFail = @($group.Group | Where-Object Status -eq 'FAIL').Count
    $categoryError = @($group.Group | Where-Object Status -eq 'ERROR').Count
    $categoryInfo = @($group.Group | Where-Object Status -eq 'INFO').Count
    $categoryNa = @($group.Group | Where-Object Status -eq 'NA').Count
    $categoryStatus = if ($categoryFail -gt 0 -or $categoryError -gt 0) {
        'FAIL'
    } elseif ($categoryWarn -gt 0) {
        'WARN'
    } elseif ($categoryPass -gt 0) {
        'PASS'
    } else {
        'INFO'
    }

    [PSCustomObject][ordered]@{
        Category = 'Summary by Category'
        Check    = $group.Name
        Status   = $categoryStatus
        Expected = 'No failures, errors, or warnings'
        Actual   = "Pass=$categoryPass; Warn=$categoryWarn; Fail=$categoryFail; Error=$categoryError; Info=$categoryInfo; NA=$categoryNa"
        Details  = "Total=$($group.Count)"
    }
}

$displayResults = if ($IssuesOnly) {
    @($script:Results | Where-Object Status -in @('WARN', 'FAIL', 'ERROR'))
} else {
    @($script:Results)
}
$displayCategorySummary = if ($IssuesOnly) {
    @($categorySummary | Where-Object Status -in @('WARN', 'FAIL'))
} else {
    @($categorySummary)
}

if ($ConsoleOutput) {
    Show-ConsoleReport -Summary $summary -CategorySummary $displayCategorySummary -Results $displayResults -IncludeDetails:$VerboseStandalone
} elseif ($ObjectOutput) {
    $summary
    $displayCategorySummary
    $displayResults
} else {
    New-ConnectReport -Summary $summary -Results $displayResults
}
