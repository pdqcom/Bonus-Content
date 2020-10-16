Get-NetIPInterface -AddressFamily ipv6 | foreach{
   $rfc = (& netsh int ipv6 show int $_.ifIndex) -match '(RFC 6106)'
   if($rfc -like "*enabled"){
        netsh int ipv6 set int $_.ifIndex rabaseddnsconfig=disable
   }
}
