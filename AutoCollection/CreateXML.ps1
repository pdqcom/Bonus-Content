 ###Set Parameters
 [CmdletBinding(PositionalBinding=$false)]
 param(
    [Parameter(Mandatory=$true)][string]$VariableName,
    [Parameter(Mandatory=$true)][string]$ApplicationName,
    [Parameter(Mandatory=$true)][string]$VariableVersionName,
    [Parameter(Mandatory=$true)][string]$ApplicationVersion,
    [Switch]$VersionInTitle = $false
 )

 
 ###Create Filename
$FileName = $ApplicationName + ".xml"
###Get Exsiting XML and replace placeholder information with params
$file = Get-Content -Path "$PSScriptRoot\Name of your Application.xml" | ForEach-Object{$_.replace("AppNameApp",$VariableName).Replace("AppVerApp","$VariableVersionName").replace("Name of your Application","$ApplicationName").replace("Version of your Application","$ApplicationVersion")}
###If Application Name Contains version
If($VersionInTitle){
   $file = $file.replace("<Comparison>Equals</Comparison>","<Comparison>StartsWith</Comparison>")
}
###Export new xml
$FinalExport = [xml]$file
$FinalExport.'AdminArsenal.Export'.InnerXml | Out-File -FilePath "$PSScriptRoot\$FileName"
