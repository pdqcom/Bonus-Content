$UserName = "Domain\UserName
$PasswordFile = ".\Password.txt"
$keyfile = ".\AES.key"
$Key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $Key)

Test-ComputerSecureChannel -Repair -Server "v-dc1-web.web.pdq.com" -Credential $MyCredential
