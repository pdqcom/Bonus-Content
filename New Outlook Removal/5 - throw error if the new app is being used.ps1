# This is the path where New Outlook keeps logs
$targetFolder = "AppData\Local\Microsoft\Olk\Logs"

# Get all user profile directories
$userProfiles = Get-ChildItem "C:\Users" -Directory

# Loop through each user profile and check for files
foreach ($profile in $userProfiles) {
    $logFolderPath = "C:\Users\$($profile.Name)\$targetFolder"

    if (Test-Path $logFolderPath) {
        $files = Get-ChildItem -Path $logFolderPath -File -ErrorAction SilentlyContinue
        if ($files) {

            $filesFound = $true
            Write-Output "Files FOUND in: $logFolderPath"
            $files | ForEach-Object { Write-Output "  -> $($_.Name)" }
        }
        else {
            Write-Output "Folder exists but NO files found in: $logFolderPath"
        }
    }
    else {
        Write-Output "Folder NOT found for user: $($profile.Name)"
    }
}

# We need to stop this boat if the user uses New Outlook! Throw an errorrrrrr
if ($filesFound) {
    throw "Files were found! throwing error"
}
else {
    Write-Output "No files found, all good!"
}