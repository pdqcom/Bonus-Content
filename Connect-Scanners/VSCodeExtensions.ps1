Get-ChildItem "C:\Users\*\.vscode\extensions\*" -Directory |
    ForEach-Object {
        if ($_.Name -match '^(?<publisher>[^.]+)\.(?<name>.+)-(?<version>[\d.]+)$') {
            [PSCustomObject]@{
                User      = $_.FullName.Split('\')[2]
                Publisher = $matches['publisher']
                Name      = $matches['name']
                Version   = $matches['version']
            }
        }
    }
