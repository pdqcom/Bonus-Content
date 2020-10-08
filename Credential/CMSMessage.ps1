$oid = [System.Security.Cryptography.Oid]::new('1.3.6.1.4.1.311.80.1')
$coll = [System.Security.Cryptography.OidCollection]::new()
[void]$coll.Add($oid)
$ext = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($coll, $true)
New-SelfSignedCertificate -Subject 'pdq@example.com' -HashAlgorithm SHA256 -KeyUsage  KeyEncipherment, DataEncipherment -KeyLength 4096 -CertStoreLocation Cert:\CurrentUser\My\ -KeySpec KeyExchange -KeyExportPolicy Exportable -Extension $ext 
$cred = Get-Credential
$msg = $cred.GetNetworkCredential().Password | Protect-CmsMessage -To *pdq@example.com
$msg
$msg | Unprotect-CmsMessage