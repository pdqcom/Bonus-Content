$shell = New-Object -ComObject "Shell.Application"
$shell.minimizeall()

$text = "In order to operate efficently and install updates this computer must be restarted periodically.`r `rRestart computer now?"
Add-Type -AssemblyName PresentationFramework

$msgBoxInput = [System.Windows.MessageBox]::Show($text,'Restart Computer','YesNo','Error')
switch ($msgBoxInput) {

'Yes' {

Restart-Computer

}

'No' {


}


}
exit
