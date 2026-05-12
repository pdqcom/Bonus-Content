# Don't forget to run PowerShell as ADmin!

Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2 } -MaxEvents 100

# Event Log Levels:
# 1 = Critical     - system/app failure, cannot continue
# 2 = Error        - serious problem, but still running
# 3 = Warning      - something needs attention
# 4 = Information  - normal operation details
# 5 = Verbose      - detailed diagnostics
# 0 = LogAlways    - always logged (rare)


# if you have an event, just grab it directly
# Filter based on time
$since = (Get-Date).AddDays(-12)
Get-WinEvent -FilterHashtable @{
  LogName   = 'Security'
  Id        = 4625
  StartTime = $since
} | Select TimeCreated, Id, @{N='User';E={($_.Properties[5].Value)}}, Message



