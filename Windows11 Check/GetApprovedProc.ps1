$URI = "https://docs.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-intel-processors","https://docs.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-amd-processors","https://docs.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-qualcomm-processors"
$table = @()
$proc =  Get-CimInstance -class CIM_Processor | Select-Object Name

foreach($Address in $URI){
    $Result = Invoke-WebRequest $Address
    $data = ($Result.ParsedHtml.getElementsByTagName("table") | Select-Object -First 1).rows


    forEach($row in $data){
        if($row.tagName -eq "tr"){
            $thisRow = @()
            $cells = $row.children
            forEach($cell in $cells){
            if($cell.tagName -imatch "t[dh]"){
                    $thisRow += $cell.innerText
                }
            }
            $table += $thisRow -join ","
        }
    }
}

$final = $table | ConvertFrom-Csv -Delimiter "," | Export-csv $home\proc.csv -NoTypeInformation
