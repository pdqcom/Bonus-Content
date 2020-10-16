Get-NetIPInterface -AddressFamily ipv6 | foreach{
   [PSCustomObject]@{
        "IfIndex"   = (& netsh int ipv6 show int $_.ifIndex) -match 'IfIndex' -replace "ifindex\s*:","" | Out-String
        "RFC"   = (& netsh int ipv6 show int $_.ifIndex) -match '(RFC 6106)' -replace "RA Based DNS Config \(RFC 6106\)\s*:","" | Out-String
    }
}
