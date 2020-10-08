#Creating Credential Objects

##These are DPAPI and will only work on the machine and user account you created them on
#How Jordan did this early on in his career
$passwordfile = "C:\temp\password.txt"
$password = "WhydidIdothis?" | ConvertTo-SecureString -AsPlainText -Force
$password | ConvertFrom-SecureString | Out-File $passwordfile

#Little Bit better
$passwordfile = "C:\temp\password.txt"
$password = Read-Host -AsSecureString -Prompt "Give me that sweet sweet password"
$password | ConvertFrom-SecureString | Out-File $passwordfile



#Probably the way we should go about it
$passwordfile = "C:\temp\password.txt"
$password = (Get-credential).Password
$password | ConvertFrom-SecureString | Out-File $passwordfile
