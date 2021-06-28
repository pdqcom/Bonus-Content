# Postgres ODBC - Driver link - https://www.postgresql.org/ftp/odbc/versions/msi/

$PostgresCredential = Import-Clixml -Path '\\Server\Credentials\PostgresCred_web.xml'
$ComputerName = 'S19-DB3-LAB'
$Port = '5432'
$Query = 'SELECT datname FROM pg_database;'

$ConnectionString = "driver={PostgreSQL Unicode(x64)};server=$ComputerName;port=$Port;uid=$($PostgresCredential.UserName);pwd=$($PostgresCredential.GetNetworkCredential().password)"
$Connection = [System.Data.Odbc.OdbcConnection]::new($ConnectionString)
$Connection.Open()

$Command = New-Object System.Data.Odbc.OdbcCommand($Query, $Connection)

$Dataset = New-Object system.Data.DataSet
$DataAdapter = New-Object system.Data.odbc.odbcDataAdapter($Command)
$RecordCount = $DataAdapter.fill($Dataset)
$Dataset.Tables
$Connection.close()


