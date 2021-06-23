[CmdletBinding()]
Param(
    [string]$BadEmailList, #Location of CSV report of computers that don't have a valid email
    [string]$DBPath = "C:\programdata\Admin Arsenal\PDQ Inventory\Database.db",#Inventory DB Path, this is the default.
    [String]$keyfile,#If you create a credential file with a key, this is the location of your keyfile
    [String]$PasswordFile,#Password Location, if you did not create this as a secure string then you will want to change [string] to [securestring] to make sure you are not passing clear text passwords
    [string]$MailFrom,#Email address you want to send as
    [string]$SMTP,#SMTP server
    [int]$Port = "587",
    [int]$CollectionID, #This is the ID number of your inventory Collection. you can use the CLI to find this "pdqinventory getcollection CollectionName"
    [int]$CustomFieldID #CustomFieldID for the email address "Select * From CustomComputerItems" | sqlite3.exe $dbpath"
)
###SQL Query to get list of computers that have not logged into the VPN in some time
$SQLQuery = "SELECT 
    Computers.Name,
    Value
FROM CollectionComputers
    INNER JOIN Computers 
        ON Computers.ComputerID = CollectionComputers.ComputerID
    LEFT JOIN CustomComputerValues 
        ON CustomComputerValues.ComputerID = CollectionComputers.ComputerID AND CustomComputerValues.CustomComputerItemID = $CustomFieldID
WHERE
    CollectionID = $CollectionID"
$TehEmails = $SQLQuery | sqlite3.exe $DBPath
$InvalidEmails = New-Object System.Collections.ArrayList
###Building your credential object, this example uses a key file and a password file that needs the key file to decrypt, Any you prefer for building the credential will work here, you will need to Make some changes to the build part however
$Key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $MailFrom, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $Key)
### For Each entry if the email column is valid then email the user
Foreach($entry in $TehEmails){
    If($entry.Split("|")[1] -as [System.Net.Mail.MailAddress] ){
        $email = @{
            To = $entry.Split("|")[1]
            Body = "Hello fellow human, I, with my human eyes, have noticed that your computer named: $($entry.Split("|")[0]) needs updates installed. I and all the other non-robots believe that you should connect this to the VPN So we can install these completely noninvasive updates that will in no way invade your privacy."
            From = $MailFrom
            Subject = "You Should VPN buddy!"
            SmtpServer = "smtp.gmail.com"
            Port = $Port
            UseSSL = $true
            Credential = $MyCredential
        }
        Send-MailMessage @email
    }else{
        ###If email is blank or does now pass as a valid email add to array
        $bademail = [PSCustomObject]@{
            Name = $entry.Split("|")[0]
        }
        $InvalidEmails.Add($bademail) | Out-Null
    }
}
##Email yourself for all entries that have not connected that do not have a valid email
If($InvalidEmails){
    $InvalidEmails | Export-CSv -Force -NoTypeInformation -Path $BadEmailList
    $email = @{
        To = "jordan.hammond@pdq.com"
        Body = "Please see attached file to see all computers that have an issue with their custom fields"
        From = $MailFrom
        Subject = "THE EMAILS! THEY ARE NOT WORKING!!!"
        SmtpServer = $SMTP
        Port = $Port
        UseSSL = $true
        Credential = $MyCredential
        Attachments = $BadEmailList
    }
    Send-MailMessage @email
}
