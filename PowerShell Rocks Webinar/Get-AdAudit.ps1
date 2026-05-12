#Requires -Version 7.0
<#
.SYNOPSIS
    Runs a simple Active Directory security audit using PSGuerrilla.

.DESCRIPTION
    Imports PSGuerrilla, optionally sets up the credential vault, then runs
    Invoke-Reconnaissance (175 AD checks across 10 categories). The CSV report
    is written automatically by PSGuerrilla to the configured output directory.

.PARAMETER OutputDirectory
    Directory where reports are saved. Defaults to a 'PSGuerrilla-Reports' folder
    in the current working directory.

.PARAMETER SkipSetup
    Skip Safehouse setup (use when credentials are already stored from a prior run).

.PARAMETER Force
    Auto-install PSGuerrilla dependencies without prompting.

.EXAMPLE
    .\Invoke-ADaudit.ps1

.EXAMPLE
    .\Invoke-ADaudit.ps1 -SkipSetup

.NOTES
    Requires a domain-joined machine or RSAT tools with domain credentials.
    PSGuerrilla uses your current Kerberos session for AD — no secrets are stored.
    Source: https://github.com/jimrtyler/PSGuerrilla
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PWD 'PSGuerrilla-Reports'),
    [switch]$SkipSetup,
    [switch]$Force
)

# Import PSGuerrilla, cloning it first if needed
$root = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD }
$moduleDir = Join-Path $root 'PSGuerrilla'
$manifestPath = Join-Path $moduleDir 'PSGuerrilla.psd1'

if (-not (Test-Path $manifestPath)) {
    Write-Verbose "Cloning PSGuerrilla from GitHub..."
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required to download PSGuerrilla. Install git and re-run."
    }
    git clone https://github.com/jimrtyler/PSGuerrilla.git $moduleDir
}

Import-Module $manifestPath -Force
Write-Verbose "PSGuerrilla imported."

# Patch a known upstream bug in Export-ReconnaissanceReportHtml where
# $Delta.PreviousScanTimestamp (a DateTime) has .Substring() called on it.
# Fix: cast to string first so .Substring() works correctly.
$htmlExportPath = Join-Path $moduleDir 'Private\Export\Export-ReconnaissanceReportHtml.ps1'
if (Test-Path $htmlExportPath) {
    $content = Get-Content $htmlExportPath -Raw
    $buggy   = '$Delta.PreviousScanTimestamp.Substring(0, 19)'
    $fixed   = '$Delta.PreviousScanTimestamp.ToString().Substring(0, 19)'
    if ($content -like "*$buggy*") {
        Write-Verbose "Patching PSGuerrilla DateTime bug in Export-ReconnaissanceReportHtml.ps1..."
        $content -replace [regex]::Escape($buggy), $fixed | Set-Content $htmlExportPath -NoNewline
        # Reimport the module so the patched file takes effect
        Import-Module $manifestPath -Force
    }
}

# Set up the credential vault (AD uses your current Kerberos session — nothing to store)
if (-not $SkipSetup) {
    $safeHouseParams = @{ OutputDirectory = $OutputDirectory }
    if ($Force) { $safeHouseParams['Force'] = $true }
    Set-Safehouse @safeHouseParams
} else {
    Write-Verbose "Skipping Safehouse setup."
}

# Run the audit — PSGuerrilla writes the CSV and HTML reports automatically
Write-Verbose "Running Active Directory Reconnaissance..."
Invoke-Reconnaissance
Write-Verbose "Done. Reports saved to: $OutputDirectory"
