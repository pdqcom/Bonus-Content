Get-Command -Module AdmPwd.ps
Get-ADComputer alanrails -Properties ms-Mcs-admpwd, ms-MCS-AdmPwdExpirationTime


Get-ADOrganizationalUnit -Filter *| Find-AdmPwdExtendedRights -PipelineVariable OU |ForEach{
    $_.ExtendedRightHolders|ForEach{
        [pscustomobject]@{
            OU=$Ou.ObjectDN
            Allowed = $_
        }
    }
}


$pass = (Get-AdmPwdPassword -ComputerName alanrails).Password
$lapspassword = ConvertTo-SecureString $pass -AsPlainText -Force
$LocalAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ".\LAPSAdmin", $lapspassword

Invoke-Command -ComputerName alanrails -Credential $LocalAdminCredential -ScriptBlock {
  Get-Service *xbox*
} 


Set-ADComputer alanrails -Replace @{"ms-Mcs-AdmPwdExpirationTime"=0}
Reset-AdmPwdPassword -ComputerName alanrails -WhenEffective (Get-Date).AddDays(-1)

Invoke-Command -ComputerName alanrails -Credential $LocalAdminCredential -ScriptBlock {
  GPUpdate /Force
} 