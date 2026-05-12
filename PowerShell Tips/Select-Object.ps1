
#region Show File Sizes in MB

Get-ChildItem -Path C:\Windows\System32 | Select-Object Name, @{Name='SizeMB'; Expression = { "{0:N2}" -f ($_.Length / 1MB) }}

#endregion

#region file owner and file info

Get-ChildItem -Path . -File | Select-Object Name, Length,  @{Name='Owner'; Expression = { (Get-Acl -Path $_.FullName).Owner }}

#endregion

# region multiple Calculated Properties OMG!
Get-ChildItem -Path . -File -Recurse |
 Select-Object Name, Length,
  @{Name='Owner'; Expression = { (Get-Acl -Path $_.FullName).Owner }},
  @{Name='SizeMB'; Expression = { "{0:N2}" -f ($_.Length / 1MB) }}
#endregion
