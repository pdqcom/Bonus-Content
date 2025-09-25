
# This method assumes that you use a file copy step to put the Windows 11 ISO at C:\ISO\Windows_11.iso>

Mount-DiskImage -ImagePath "C:\ISO\Windows_11.iso"

Start-Sleep -seconds 2

$Volume = Get-Volume | Where-Object { $_.FileSystemLabel -eq (Get-DiskImage -ImagePath "C:\ISO\Windows_11.iso" | Get-Volume).FileSystemLabel }
 
$DriveLetter = $Volume.DriveLetter

New-Item "C:\windows11_upgrade" -ItemType Directory

$Source = "$($DriveLetter):\"

$Destpath = "C:\windows11_upgrade\"

Start-Process robocopy -ArgumentList @($Source, $Destpath, "/MIR") -NoNewWindow -Wait

Start-Process "C:\windows11_upgrade\setup.exe" -ArgumentList "/auto upgrade /quiet /eula accept /norestartui" 
