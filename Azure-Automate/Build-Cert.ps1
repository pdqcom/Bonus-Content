$certname = "CN=SuperSecret"
$SecretName = "AppCert"
$Vault = "Vault Name"

#Build Cert
$cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject $certname -KeySpec KeyExchange
#Create Secret to allow you to use the Thumbprint in Automation. You will need to have the vault unlocked before thsi line runs https://www.pdq.com/blog/how-to-manage-powershell-secrets-with-secretsmanagement/
Set-Secret -Name $SecretName -Vault $Vault -Secret $cert.Thumbprint
