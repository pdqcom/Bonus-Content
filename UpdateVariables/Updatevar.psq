$var = [xml](Get-Content -Path "C:\temp\CustomVariables.xml")

Foreach($Variable in $var.'AdminArsenal.Export'.VariablesSettingsViewModel.CustomVariables.CustomVariable){
       pdqdeploy updatecustomvariable -Name $Variable.name -Value $Variable.Value
}
