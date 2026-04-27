# Taskbar Pinned Items per User - PDQ Connect PowerShell Scanner
# Walks every loaded user hive in HKU and every profile on disk, resolves taskbar shortcuts.

# Taskbar pins live at: %AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar
# Which resolves to: C:\Users\<name>\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar
# Each pin is a .lnk file. Parse the target with WScript.Shell COM.

$shell = New-Object -ComObject WScript.Shell

# Resolve SID to username - cached to avoid repeat lookups
$sidCache = @{}
function Resolve-SidToName {
    param([string]$Sid)
    if ($sidCache.ContainsKey($Sid)) { return $sidCache[$Sid] }
    $resolved = try {
        ([System.Security.Principal.SecurityIdentifier]$Sid).Translate([System.Security.Principal.NTAccount]).Value
    } catch { $Sid }
    $sidCache[$Sid] = $resolved
    return $resolved
}

# Map profile paths from the registry (authoritative - includes deleted users sometimes)
$profileList = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction SilentlyContinue

foreach ($profileKey in $profileList) {
    $sid = Split-Path -Path $profileKey.Name -Leaf

    # Skip service accounts (SIDs starting with S-1-5-18, -19, -20)
    if ($sid -in 'S-1-5-18', 'S-1-5-19', 'S-1-5-20') { continue }

    # Skip non-user SIDs (keep only S-1-5-21-* account SIDs)
    if ($sid -notlike 'S-1-5-21-*') { continue }

    $profilePath = (Get-ItemProperty -Path $profileKey.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
    if (-not $profilePath) { continue }

    $taskbarPath = Join-Path -Path $profilePath -ChildPath 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'

    if (-not (Test-Path -LiteralPath $taskbarPath)) { continue }

    $userName = Resolve-SidToName -Sid $sid

    $shortcuts = Get-ChildItem -LiteralPath $taskbarPath -Filter '*.lnk' -ErrorAction SilentlyContinue

    foreach ($lnk in $shortcuts) {
        try {
            $link = $shell.CreateShortcut($lnk.FullName)
            $target = $link.TargetPath

            # Detect UWP / packaged apps (they're .lnk with no traditional target)
            $isPackaged = [string]::IsNullOrWhiteSpace($target)

            $targetExists = $false
            $targetSigned = $false
            if (-not $isPackaged -and $target) {
                $targetExists = Test-Path -LiteralPath $target -ErrorAction SilentlyContinue
                if ($targetExists) {
                    try {
                        $sig = Get-AuthenticodeSignature -LiteralPath $target -ErrorAction Stop
                        $targetSigned = ($sig.Status -eq 'Valid')
                    } catch {
                        $targetSigned = $false
                    }
                }
            }

            [pscustomobject]@{
                UserName      = $userName
                UserSid       = $sid
                PinName       = [System.IO.Path]::GetFileNameWithoutExtension($lnk.Name)
                TargetPath    = if ($target) { $target } else { 'N/A (packaged app)' }
                Arguments     = if ($link.Arguments) { $link.Arguments } else { '' }
                WorkingDir    = if ($link.WorkingDirectory) { $link.WorkingDirectory } else { '' }
                IsPackagedApp = [bool]$isPackaged
                TargetExists  = [bool]$targetExists
                TargetSigned  = [bool]$targetSigned
                ShortcutFile  = $lnk.FullName
                LastModified  = $lnk.LastWriteTime
            }
        } catch {
            # Malformed .lnk - skip it
        }
    }
}

# Release the COM object
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
