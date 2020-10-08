#Create random AES Key
$Keyfile = "C:\Temp\aes.key"
$key = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().getbytes($key)
$key | Out-file $Keyfile


#creating password file
$passwordfile = "C:\Temp\password.txt"
$Keyfile = "C:\temp\aes.key"
$key = Get-Content $keyfile
$password = Read-Host -AsSecureString -Prompt "GIVE ME YOUR SECRETS!!!!!!!"
$password | ConvertFrom-SecureString -Key $key | Out-File $passwordfile