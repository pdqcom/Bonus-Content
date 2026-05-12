# Suspicious Scheduled Tasks - PDQ Connect PowerShell Scanner
# Returns one row per non-Microsoft task with a computed SuspiciousScore.
# Filter in Connect to SuspiciousScore >= 3 for high-confidence findings.

$wellKnownPrincipals = @(
    'SYSTEM', 'LOCAL SERVICE', 'NETWORK SERVICE',
    'INTERACTIVE', 'Users', 'Authenticated Users', 'Everyone',
    'S-1-5-18', 'S-1-5-19', 'S-1-5-20',
    'S-1-5-4', 'S-1-5-11', 'S-1-5-32-545', 'S-1-1-0'
)

$safeAuthorPattern = '^(Microsoft|Windows|Intel|Dell|HP|Lenovo|Adobe|Google|Zoom|Citrix|VMware|NVIDIA|AMD|Realtek|Logitech)'
$suspiciousInterpreters = @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'rundll32.exe', 'regsvr32.exe')

$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue

foreach ($task in $tasks) {

    # Get author from XML (not on the CIM object)
    $author = ''
    try {
        $xml = [xml]$task.XmlText
        if ($xml.Task.RegistrationInfo.Author) {
            $author = [string]$xml.Task.RegistrationInfo.Author
        }
    } catch { }

    $principal = [string]$task.Principal.UserId
    if (-not $principal) { $principal = [string]$task.Principal.GroupId }

    $isMsAuthored = ($author -match '^Microsoft')
    $isBuiltinPrincipal = ($wellKnownPrincipals -contains $principal)

    # Skip pure Microsoft+builtin noise
    if ($isMsAuthored -and $isBuiltinPrincipal) { continue }

    # Analyze first action
    $firstExec = ''
    $firstArgs = ''
    if ($task.Actions.Count -gt 0) {
        $firstExec = [string]$task.Actions[0].Execute
        $firstArgs = [string]$task.Actions[0].Arguments
    }

    $executableName = ''
    $pathExists = $false
    $pathIsSigned = $false
    $pathOutsideStandard = $false

    if ($firstExec) {
        $resolvedPath = [System.Environment]::ExpandEnvironmentVariables($firstExec)
        $executableName = [string](Split-Path -Path $resolvedPath -Leaf -ErrorAction SilentlyContinue)

        if (Test-Path -LiteralPath $resolvedPath -ErrorAction SilentlyContinue) {
            $pathExists = $true
            try {
                $sig = Get-AuthenticodeSignature -LiteralPath $resolvedPath -ErrorAction Stop
                $pathIsSigned = ($sig.Status -eq 'Valid')
            } catch { }

            $pathOutsideStandard = -not (
                $resolvedPath -like "$env:ProgramFiles\*" -or
                $resolvedPath -like "${env:ProgramFiles(x86)}\*" -or
                $resolvedPath -like "$env:SystemRoot\*"
            )
        }
    }

    # --- Scoring ---
    $score = 0
    $reasons = @()

    if ($pathExists -and -not $pathIsSigned) {
        $score += 2; $reasons += 'unsigned binary'
    }
    if ($pathExists -and $pathOutsideStandard) {
        $score += 2; $reasons += 'path outside standard dirs'
    }
    $principalIsRealUser = ($principal -and -not $isBuiltinPrincipal)
    if ($principalIsRealUser) {
        $score += 1; $reasons += 'runs as user account'
    }
    if ($principalIsRealUser -and [string]$task.Principal.RunLevel -eq 'Highest') {
        $score += 1; $reasons += 'user + elevated'
    }
    if (-not $author -and -not $pathIsSigned) {
        $score += 1; $reasons += 'no author metadata'
    }
    if ($executableName -and ($suspiciousInterpreters -contains $executableName.ToLower()) -and $firstArgs) {
        $score += 2; $reasons += 'script interpreter with args'
    }
    if ($author -and -not ($author -match $safeAuthorPattern)) {
        $score += 1; $reasons += 'unknown author'
    }

    [PSCustomObject]@{
        TaskName                  = $task.TaskName
        TaskPath                  = $task.TaskPath
        State                     = [string]$task.State
        Author                    = if ($author) { $author } else { 'N/A' }
        Principal                 = if ($principal) { $principal } else { 'N/A' }
        RunLevel                  = [string]$task.Principal.RunLevel
        ActionExe                 = $firstExec
        ActionArgs                = $firstArgs
        ExecutableName            = if ($executableName) { $executableName } else { 'N/A' }
        ActionPathExists          = $pathExists
        ActionPathSigned          = $pathIsSigned
        ActionPathOutsideStandard = $pathOutsideStandard
        TaskEnabled               = $task.Settings.Enabled
        TaskHidden                = $task.Settings.Hidden
        SuspiciousScore           = $score
        SuspiciousReasons         = ($reasons -join '; ')
    }
}
