[CmdletBinding()]
param (
    [int]$TPMminVer = 1.2,
    [int]$DirectxVer = 12,
    [int]$WDDMVer = 2.0
)

###Import approved Processor list
$final = Import-Csv ".\proc.csv"
###Get Procossor
$proc =  Get-CimInstance -class CIM_Processor | Select-Object Name
$ProcCompatible = $false
###Compare processor to approved list
foreach($cpu in $final.model){
    
    if($proc.name -like "*" + $cpu + "*"){
        $ProcCompatible = $true
        break
    }
}

###Test TPM
$TPMCompatible = $false
Try{$GetTPM = (Get-tpm).TPMPresent}
Catch{}
If($GetTPM -eq $true){
    $TPMVer = Get-CimInstance -Namespace "root/cimv2/Security/MicrosoftTPM" -ClassName win32_tpm | Select-Object specversion
    If($TPMVer.specversion.Split(',')[0] -ge $TPMminVer){
        $TPMCompatible = $true
    }
}

###Test UEFI
$UEFICompatible = $false

Try {$UEFI = Confirm-SecureBootUEFI}
Catch{}

If($UEFI){
    $UEFICompatible = $True
}

###Test Direct X 12
Start-Process -FilePath "C:\Windows\System32\dxdiag.exe" -ArgumentList "/dontskip /whql:off /t C:\dxdiag.txt" -Wait

###Load File into file stream
$file = New-Object System.IO.StreamReader -ArgumentList "C:\dxdiag.txt"

###Setting initial variable state
$Directx12Compatible = $false
$WDDMCompatible = $false
###Reading file line by line
try {
    while ($null -ne ($line = $file.ReadLine())) {
###Mark start of applied policies
        if ($line.contains("DDI Version:") -eq $True) {
            if($line.Trim("DDI Version: ") -ge $DirectxVer){
                $Directx12Compatible = $true
            }
        }
        elseif ($line.contains("Driver Model:") -eq $True) {
            if($line.Trim("Driver Model: WDDM ") -ge $WDDMVer){
                $WDDMCompatible = $true
            }
        }
    }
}

finally {
    $file.Close()
    Remove-Item "C:\dxdiag.txt" -Force
}

[pscustomobject]@{
    Processor = $ProcCompatible
    TPM = $TPMCompatible
    UEFI = $UEFICompatible
    Directx12 = $Directx12Compatible
    WDDM = $WDDMCompatible 
}
