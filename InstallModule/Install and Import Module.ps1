[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $ModuleName,
    [ValidateSet('CurrentUser','Allusers')]
    $Scope = 'CurrentUser'
)

# Install the module if it is not already installed, then load it.
Try {

    $null = Get-InstalledModule $ModuleName -ErrorAction Stop

} Catch {

    if ( -not ( Get-PackageProvider -ListAvailable | Where-Object Name -eq "Nuget" ) ) {

        $null = Install-PackageProvider "Nuget" -Force

    }

    $null = Install-Module $ModuleName -Force -Scope $scope

}

$null = Import-Module $ModuleName -Force

if (Get-Module $Modulename) {
    Write-Output "$ModuleName installed successfully"
    exit 0
}
else {
   Write-Error "$Modulename is not installed"
   exit 777
}
