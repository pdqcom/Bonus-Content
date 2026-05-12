<#
.SYNOPSIS
    Identifies duplicate files within a specified folder using SHA256 hash comparison.

.DESCRIPTION
    Get-DuplicateFile scans a target folder for files with identical content by computing
    SHA256 hashes and grouping matches. Only files with two or more copies are returned,
    sorted by hash then file name.

    Output objects bind to Remove-Item via the Path property, so you can pipe results
    directly to remove duplicates:

        Get-DuplicateFile -Path C:\Downloads | Select-Object -Skip 1 | Remove-Item -WhatIf

.PARAMETER Path
    The folder path to scan for duplicate files. Must be a valid, existing directory.

.PARAMETER Recurse
    When specified, subdirectories are included in the scan.

.PARAMETER Filter
    File filter pattern to limit which files are scanned (e.g., '*.txt'). Defaults to
    all files ('*') when not specified.

.EXAMPLE
    Get-DuplicateFile -Path 'C:\Downloads'

    Scans C:\Downloads for duplicate files and returns matching groups.

.EXAMPLE
    Get-DuplicateFile -Path 'C:\Projects' -Recurse -Verbose

    Recursively scans C:\Projects with verbose progress output.

.EXAMPLE
    Get-DuplicateFile -Path 'C:\Documents' -Filter '*.pdf' | Format-Table -AutoSize

    Finds duplicate PDF files and displays results in a table.

.EXAMPLE
    Get-DuplicateFile -Path 'C:\Downloads' |
        Group-Object Hash |
        ForEach-Object { $_.Group | Select-Object -Skip 1 } |
        Remove-Item -WhatIf

    Preview removal of all but the first copy of each duplicate group.

.EXAMPLE
    1..3 | ForEach-Object { "duplicate content" | Out-File ".\testfile_$_.txt" }; Copy-Item .\testfile_1.txt .\testfile_1_copy.txt; "unique content" | Out-File .\unique.txt

    Populate the current directory with test files: three files sharing identical content
    (testfile_1.txt through testfile_3.txt), one copy of testfile_1 (testfile_1_copy.txt),
    and one unique file (unique.txt). Run Get-DuplicateFile afterward to verify results.

.NOTES
    Author  : @AndrewPlaTech
    Version : 1.0.0
    Hashing : SHA256 via Get-FileHash
#>
[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [System.IO.DirectoryInfo] $Path = (Get-Location).Path,

    [Parameter()]
    [switch] $Recurse,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Filter = '*'
)

#region --- Validation ---

if (-not $Path.Exists) {
    Write-Error "Path '$($Path.FullName)' does not exist or is not a directory." -ErrorAction Stop
}

#endregion

#region --- File Discovery ---

$StartTime = [System.Diagnostics.Stopwatch]::StartNew()

$GetChildItemParams = @{
    LiteralPath = $Path.FullName
    File        = $true
    Filter      = $Filter
    Recurse     = $Recurse.IsPresent
    ErrorAction = 'SilentlyContinue'
}

Write-Verbose "Scanning '$($Path.FullName)' (Recurse=$($Recurse.IsPresent), Filter='$Filter')..."

$AllFiles = Get-ChildItem @GetChildItemParams
$TotalFileCount = $AllFiles.Count

Write-Verbose "Discovered $TotalFileCount file(s). Computing hashes..."

#endregion

#region --- Hash Computation ---

$HashedFiles = New-Object 'System.Collections.Generic.List[PSCustomObject]'
$ProcessedCount = 0

foreach ($File in $AllFiles) {
    $ProcessedCount++

    # Log progress every 50 files and always on the last file to avoid flooding verbose output
    if ($ProcessedCount % 50 -eq 0 -or $ProcessedCount -eq $TotalFileCount) {
        Write-Verbose "  Hashed $ProcessedCount / $TotalFileCount file(s)..."
    }

    try {
        $HashResult = Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256 -ErrorAction Stop

        $HashedFiles.Add([PSCustomObject]@{
            FullName = $File.FullName
            Name     = $File.Name
            Length   = $File.Length
            Hash     = $HashResult.Hash
        })
    }
    catch {
        Write-Error "Failed to hash '$($File.FullName)': $_"
    }
}

#endregion

#region --- Duplicate Detection & Output ---

# Group by hash; keep only groups with 2+ members (true duplicates)
$DuplicateGroups = $HashedFiles |
    Group-Object -Property Hash |
    Where-Object { $_.Count -ge 2 }

# Sum the Count property across all duplicate groups to get the total number of duplicate files
$DuplicateFileCount = ($DuplicateGroups | Measure-Object -Property Count -Sum).Sum
$StartTime.Stop()

Write-Verbose "Scan complete. Files scanned: $TotalFileCount | Duplicate files: $DuplicateFileCount | Elapsed: $($StartTime.Elapsed.ToString('hh\:mm\:ss\.fff'))"

foreach ($Group in $DuplicateGroups) {
    $DuplicateCount = $Group.Count

    # Sort within each hash group by file name for consistent ordering
    $Group.Group |
        Sort-Object -Property Name |
        ForEach-Object {
            [PSCustomObject]@{
                Path           = $_.FullName
                FileName       = $_.Name
                Size           = $_.Length
                Hash           = $_.Hash
                DuplicateCount = $DuplicateCount
            }
        }
}

#endregion
