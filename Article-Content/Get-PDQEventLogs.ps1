$OutputPath = $env:TEMP

#xPathQuery for wevutil to grab event logs from Deploy, Inventory, Inventory Agent, and .NET Runtime from the last 30 days:
$xPathQuery = "*[System[Provider[@Name='PDQ Deploy' or @Name='PDQ Inventory' or @Name='PDQ Inventory Agent' or @Name='.NET Runtime'] and TimeCreated[timediff(@SystemTime) <= 2592000000]]]"
wevtutil export-log Application $OutputPath\PDQEventLogs.evtx /query:"$xPathQuery" /overwrite:true #export event logs to evtx file based on xPathQuery

$wshell = New-Object -ComObject Wscript.Shell # Create message box
$wshell.Popup("Log files saved at $OutputPath\PDQEventLogs.evtx.`n`nClick Ok to open containing folder.", 0, "PDQ Event Logs", 0x0)

Invoke-Item $OutputPath #Open up the Log folder in explorer for easy access to PDQEventLogs.evtx