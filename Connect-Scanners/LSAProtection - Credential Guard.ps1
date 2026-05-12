# LSA Protection + Credential Guard State - PDQ Connect PowerShell Scanner
# Returns a single row per device with the state of key credential-theft protections.

$runAsPplConfigured = $false
$runAsPplValue = 0
try {
    $lsaKey = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -ErrorAction Stop
    if ($null -ne $lsaKey.RunAsPPL) {
        $runAsPplValue = [int]$lsaKey.RunAsPPL
        $runAsPplConfigured = ($runAsPplValue -in 1, 2)
    }
} catch { }

$lsaCfgFlags = 0
try {
    $lsaCfgFlags = [int](Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA' -Name 'LsaCfgFlags' -ErrorAction Stop).LsaCfgFlags
} catch { }

$vbsAvailable = $false
$vbsRunning = $false
$credGuardConfigured = $false
$credGuardRunning = $false
$hvciRunning = $false

try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop

    $vbsStatus = [int]$dg.VirtualizationBasedSecurityStatus
    $vbsAvailable = ($vbsStatus -ge 1)
    $vbsRunning = ($vbsStatus -eq 2)

    $credGuardConfigured = ($dg.SecurityServicesConfigured -contains 1)
    $credGuardRunning = ($dg.SecurityServicesRunning -contains 1)
    $hvciRunning = ($dg.SecurityServicesRunning -contains 2)
} catch { }

$tpmPresent = $false
$tpmEnabled = $false
try {
    $tpm = Get-CimInstance -ClassName Win32_Tpm -Namespace 'root\CIMV2\Security\MicrosoftTpm' -ErrorAction Stop
    if ($tpm) {
        $tpmPresent = $true
        $tpmEnabled = [bool]$tpm.IsEnabled_InitialValue
    }
} catch { }

$secureBootEnabled = $false
try {
    $secureBootEnabled = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
} catch { }

$os = Get-CimInstance -ClassName Win32_OperatingSystem
$isServer = ($os.ProductType -ne 1)

[PSCustomObject]@{
    LsaProtectionConfigured    = [bool]$runAsPplConfigured
    LsaProtectionRegistryValue = [int]$runAsPplValue
    LsaCfgFlagsValue           = [int]$lsaCfgFlags
    VbsAvailable               = [bool]$vbsAvailable
    VbsRunning                 = [bool]$vbsRunning
    CredentialGuardConfigured  = [bool]$credGuardConfigured
    CredentialGuardRunning     = [bool]$credGuardRunning
    HvciRunning                = [bool]$hvciRunning
    TpmPresent                 = [bool]$tpmPresent
    TpmEnabled                 = [bool]$tpmEnabled
    SecureBootEnabled          = [bool]$secureBootEnabled
    IsServer                   = [bool]$isServer
    OsCaption                  = [string]$os.Caption
    AssessedAt                 = Get-Date
}
