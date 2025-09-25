<#
.DESCRIPTION
    This script audits, deletes, or moves orphaned files in the $env:windir\Installer directory.

    Inspired by:
        https://www.homedev.com.au/free/patchcleaner
        https://www.bryanvine.com/2015/06/powershell-script-cleaning-up.html
        https://p0w3rsh3ll.wordpress.com/2012/01/10/working-with-the-windowsinstaller-installer-object/
        https://stackoverflow.com/questions/29937568/how-can-i-find-the-product-guid-of-an-installed-msi-setup
        https://evotec.xyz/getting-file-metadata-with-powershell-similar-to-what-windows-explorer-provides/

.PARAMETERS 
    -ActionType
        Specifies the action to perform. Audit, Delete, or Move. Audit is default and only shows what would be removed.
  
    -Destination
        Required if ActionType is Move. Orhpaned files are moved to this directory. Target directory must exist.

.EXAMPLE

    Confirm which files are to be removed:
    .\Cleanup-WindowsInstallerDirectory.ps1 -ActionType Audit

    Delete orphaned files:
    .\Cleanup-WindowsInstallerDirectory.ps1 -ActionType Delete

    Move orphaned files:
    .\Cleanup-WindowsInstallerDirectory.ps1 -ActionType Move -Destination "E:\backup"

#>

#Requires -RunAsAdministrator

param(
    [ValidateSet("Audit", "Delete", "Move")]
    [string]$ActionType = "Audit",
    
    [string]$Destination
)

# Products to be excluded based on product name (partial match works)
$excludedProducts = @(
    'Adobe', #Leave Adobe to match PatchCleaner default functionality.
    'ExampleProduct'
)

function Get-FileMetaData {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)][Object] $File,
        [switch] $Signature
    )
    Process {
        foreach ($F in $File) {
            $MetaDataObject = [ordered] @{}
            if ($F -is [string]) {
                $FileInformation = Get-ItemProperty -Path $F
            } elseif ($F -is [System.IO.DirectoryInfo]) {
                #Write-Warning "Get-FileMetaData - Directories are not supported. Skipping $F."
                continue
            } elseif ($F -is [System.IO.FileInfo]) {
                $FileInformation = $F
            } else {
                Write-Warning "Get-FileMetaData - Only files are supported. Skipping $F."
                continue
            }
            $ShellApplication = New-Object -ComObject Shell.Application
            $ShellFolder = $ShellApplication.Namespace($FileInformation.Directory.FullName)
            $ShellFile = $ShellFolder.ParseName($FileInformation.Name)
            $MetaDataProperties = [ordered] @{}
            # Edited line below from 0..400 for speed improvement since we only care about Authors, Title, and Subject
            20..22 | ForEach-Object -Process {
                $DataValue = $ShellFolder.GetDetailsOf($null, $_)
                $PropertyValue = (Get-Culture).TextInfo.ToTitleCase($DataValue.Trim()).Replace(' ', '')
                if ($PropertyValue -ne '') {
                    $MetaDataProperties["$_"] = $PropertyValue
                }
            }
            foreach ($Key in $MetaDataProperties.Keys) {
                $Property = $MetaDataProperties[$Key]
                $Value = $ShellFolder.GetDetailsOf($ShellFile, [int] $Key)
                if ($Property -in 'Attributes', 'Folder', 'Type', 'SpaceFree', 'TotalSize', 'SpaceUsed') {
                    continue
                }
                If (($null -ne $Value) -and ($Value -ne '')) {
                    $MetaDataObject["$Property"] = $Value
                }
            }
            # Commented out sections that are not needed for this script to improve performance
            <#
            if ($FileInformation.VersionInfo) {
                $SplitInfo = ([string] $FileInformation.VersionInfo).Split([char]13)
                foreach ($Item in $SplitInfo) {
                    $Property = $Item.Split(":").Trim()
                    if ($Property[0] -and $Property[1] -ne '') {
                        $MetaDataObject["$($Property[0])"] = $Property[1]
                    }
                }
            }
            $MetaDataObject["Attributes"] = $FileInformation.Attributes
            $MetaDataObject['IsReadOnly'] = $FileInformation.IsReadOnly
            $MetaDataObject['IsHidden'] = $FileInformation.Attributes -like '*Hidden*'
            $MetaDataObject['IsSystem'] = $FileInformation.Attributes -like '*System*'
            #>
            if ($Signature) {
                $DigitalSignature = Get-AuthenticodeSignature -FilePath $FileInformation.Fullname
                $MetaDataObject['SignatureCertificateSubject'] = $DigitalSignature.SignerCertificate.Subject
                <#
                $MetaDataObject['SignatureCertificateIssuer'] = $DigitalSignature.SignerCertificate.Issuer
                $MetaDataObject['SignatureCertificateSerialNumber'] = $DigitalSignature.SignerCertificate.SerialNumber
                $MetaDataObject['SignatureCertificateNotBefore'] = $DigitalSignature.SignerCertificate.NotBefore
                $MetaDataObject['SignatureCertificateNotAfter'] = $DigitalSignature.SignerCertificate.NotAfter
                $MetaDataObject['SignatureCertificateThumbprint'] = $DigitalSignature.SignerCertificate.Thumbprint
                $MetaDataObject['SignatureStatus'] = $DigitalSignature.Status
                $MetaDataObject['IsOSBinary'] = $DigitalSignature.IsOSBinary
                #>
            }
            [PSCustomObject] $MetaDataObject
        }
    }
}

# Validate destination if "Move" action
if ($ActionType -eq "Move" -and -not $Destination) {
    throw [System.ArgumentException]::new("The -Destination parameter is required when -ActionType is 'Move'.")
}
if ($ActionType -eq "Move") {
    if (-not (Test-Path -Path $Destination)) {
        throw [System.ArgumentException]::new("The Destination `"$Destination`" does not exist.")
    }
}

# Create Windows Installer COM object and add new member types
$Installer = New-Object -ComObject WindowsInstaller.Installer 
$Installer | Add-Member -Name 'InvokeMethod' -MemberType ScriptMethod -Value {
    $type = $this.GetType()
    $index = $args.Count - 1
    $methodargs = $args[1..$index]
    $type.invokeMember($args[0], [System.Reflection.BindingFlags]::InvokeMethod, $null, $this, $methodargs)
}
$Installer | Add-Member -Name 'GetProperty' -MemberType ScriptMethod -Value {
    $type = $this.GetType()
    $index = $args.Count - 1
    $methodargs = $args[1..$index]
    $type.invokeMember($args[0], [System.Reflection.BindingFlags]::GetProperty, $null, $this, $methodargs)
}

# Get a list of installed MSI products
$InstallerProducts = $Installer.ProductsEx("", "", 7)
$InstalledProducts = foreach ($Product in $InstallerProducts){
    try {
        [PSCustomObject]@{
            ProductCode   = $Product.ProductCode()
            LocalPackage  = $Product.InstallProperty("LocalPackage")
            VersionString = $Product.InstallProperty("VersionString")
            ProductName   = $Product.InstallProperty("ProductName")
        }
    }
    catch {
        # Suppress errors for products missing certain properties
    }
}

# Get a list of MSP patches using the members added to $Installer
$products = $Installer.GetProperty('Products')
$InstalledPatches = foreach ($productCode in $products) {
    $patches = $Installer.GetProperty('Patches', $productCode)

    if ($patches) {
        foreach ($patchCode in $patches) {
            $location = $Installer.GetProperty('PatchInfo', $patchCode, 'LocalPackage')
            if ($location) {
                $productName = $Installer.GetProperty('ProductInfo', $productCode, 'ProductName')                
                [PSCustomObject]@{
                    ProductCode  = $productCode
                    PatchCode    = $patchCode
                    LocalPackage = $location
                    ProductName  = $productName
                }
            }
        }
    }
}

# Display all installed products and patches if Audit mode.
if ($ActionType -eq "Audit") {
    Write-Output "Installed Products:"
    if ($InstallerProducts) {
        Write-Output $InstalledProducts | Sort-Object -Property ProductName | Format-Table -AutoSize | Out-String -Width 1000
        Write-Output ""
    }
    else {
        Write-Output "No installed products`n"
    }
    Write-Output "Installed Patches:"
    if ($InstalledPatches) {
        Write-Output $InstalledPatches | Sort-Object -Property ProductName | Format-Table -AutoSize | Out-String -Width 1000
        Write-Output ""
    }
    else {
        Write-Output "No installed patches`n"
    }
    Write-Output "############# AUDIT MODE #############"
}

$totalSize = 0
$ExcludedFiles = New-Object 'System.Collections.Generic.List[PSCustomObject]'
$files = Get-ChildItem -Path $env:windir\Installer\* -Include "*.msi","*.msp"

# Determine which files are to be kept/removed
foreach ($file in $files) {
    $fullname = $file.FullName
    $fileSize = $file.Length
    
    if (
        ($InstalledProducts | Where-Object { $_.LocalPackage -eq "$fullname" }) -or
        ($InstalledPatches | Where-Object { $_.LocalPackage -eq "$fullname" })
    ) {
        #Keep file - no action needed
    }
    else {
        $metaData = $file | Get-FileMetaData -Signature | Select-Object Authors, Title, Subject, SignatureCertificateSubject
        $excludedFile = $false
        foreach ($item in $excludedProducts) {
            if (
                ($metaData.Authors -like "*$item*") -or
                ($metaData.Title -like "*$item*") -or
                ($metaData.Subject -like "*$item*") -or
                ($metaData.SignatureCertificateSubject -like "*$item*")
            ) {
                $ExcludedFiles.Add([PSCustomObject]@{
                    FileName = $fullname
                    Reason   = "Matched exclusion filter: $item"
                })
                $excludedFile = $true
                break
            }
        }

        if (-not ($excludedFile)) {
            $totalSize += $fileSize
            switch ($ActionType) {
                "Audit" {
                    Write-Output "AUDIT MODE: $fullname would be moved/deleted"
                }    
                "Delete" {
                    Write-Output "Deleting $fullname"
                    Remove-Item -Path $fullname -Force
                }
                "Move" {
                    Write-Output "Moving $fullname"
                    Move-Item -Path $fullname -Destination "$destination" -Force
                }
            }
        }
    }
}

if ($ExcludedFiles.Count -gt 0) {
    Write-Output "`nExcluded Files:"
    $ExcludedFiles | Format-Table -AutoSize
}

if ($totalSize -gt 0) {
    if ($totalSize -lt 1073741824) {
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
        Write-Output "Total space saved: $totalSizeMB MB"    
    }
    else {
        $totalSizeGB = [math]::Round($totalSize / 1GB, 2)
        Write-Output "Total space saved: $totalSizeGB GB"
    }
}
else {
    Write-Output "No space would be saved."
}