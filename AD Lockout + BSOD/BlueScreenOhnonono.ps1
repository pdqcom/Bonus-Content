<#
1001 - Windows blue-screened, here’s the stop code
41 = Windows noticed the last shutdown wasn’t clean.
6008 = The system shutdown was unexpected (logged afterward).
#>

# BugCheck summary
Get-WinEvent -FilterHashtable @{ LogName='System'; Id=1001 } |
  Select-Object TimeCreated, Id, ProviderName, Message -First 5

# Related unexpected shutdowns
Get-WinEvent -FilterHashtable @{ LogName='System'; Id=@(41,6008) } |
  Select-Object TimeCreated, Id, ProviderName, Message -First 10

# Any WER crash records referencing wininit.exe
Get-WinEvent -LogName Application |
  Where-Object { $_.ProviderName -eq 'Windows Error Reporting' -and $_.Message -match 'wininit.exe' } |
  Select-Object TimeCreated, Id, Message -First 10


# good things to try
sfc /scannow
DISM /Online /Cleanup-Image /RestoreHealth
chkdsk C: /scan

# use Windbg and perfmon
perfmon /rel #get timeline view

# update your drivers, look for others experiencing this, cross your fingers
