$username = 'jmontana'

# grab your locked out user
Get-ADUser -Identity $username -Server DC1-S22-WEB -Properties LockedOut, BadPwdCount, LastBadPasswordAttempt | 
Select-Object SamAccountName, LockedOut, BadPwdCount, LastBadPasswordAttempt

# Grab ALL locked out accounts - ty tara 🏄‍♀️
# use caution in huge environments
    Get-ADUser -Filter * -Properties lockedout, LastBadPasswordAttempt,BadPwdCount |
    Where-object {$_.Lockedout -eq $true}
    Select-Object SamAccountName, LockedOut, BadPwdCount, LastBadPasswordAttempt


# Where is dat PDC?
$PDC = Get-ADDomain | Select-Object -ExpandProperty  PDCEmulator # Looks good to me!

# Get more visibility into your servers
# All DCs (quick view)
Get-ADDomainController -Filter * |
  Select-Object Name,HostName,IPv4Address,Site,IsPdc,IsGlobalCatalog

# Domain lockout policy
Get-ADDefaultDomainPasswordPolicy |
  Select-Object LockoutThreshold,LockoutDuration,LockoutObservationWindow

# Check for the DC that processed the bad password
# You may need to temporarily increase the size of your security log - this will eat your ram tho🍪

Invoke-Command -ComputerName $pdc -ScriptBlock { Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id      = 4740
        StartTime = (Get-Date).AddDays(-1)
    } | Select-Object TimeCreated,
    @{n = 'DC'; e = { $_.MachineName } },
    @{n = 'TargetUser'; e = { $_.Properties[0].Value } },
    @{n = 'CallerComputer'; e = { $_.Properties[1].Value } }
}



#endregion

#region auditing
# If you need to verify that auditing is enabled
# Run on a DC (or remotely via PSRemoting) to confirm
auditpol /get /subcategory:"User Account Management"
# If Success is not Enabled:
auditpol /set /subcategory:"User Account Management" /success:enable
#endregion


#region Credential Manager
# List all stored creds
cmdkey /list

# Delete a stored cred by target
cmdkey /delete:TERMSRV/servername

#endregion

#region Unlock user account
# Unlock the user account
Unlock-ADAccount -Identity $username -Server DC1-S22-WEB

#endregion