# https://docs.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server?view=sql-server-2017


$SqlServerCredential = Import-Clixml -Path '\\Server\Credentials\SqlServerDBCred_web.xml'
$ComputerName = 'S19-DB1-LAB'
$Port = '1433'

$DropQuery = @'
Use Futurama;
DROP Characters;
'@

$CreateQuery = @'
USE Futurama;
CREATE TABLE Characters (
    ID int IDENTITY(1,1) PRIMARY KEY,
    Name varchar(50) NOT NULL
);
'@


$DeleteQuery = @'
USE Futurama;
DELETE FROM Characters;
'@

$InsertQuery = @'
USE Futurama;
INSERT INTO Characters
VALUES 
    ('Fry'),
    ('Bender'),
    ('Leela'),
    ('Zapp'),
    ('Kiff'),
    ('Zoidberg')
'@

$SelectQuery = 'USE Futurama; SELECT * FROM Characters;'

# Using ODBC
$ConnectionString = "driver={ODBC Driver 17 for SQL Server};server=$ComputerName,$Port;database=Futurama;uid=$($SqlServerCredential.UserName);pwd=$($SqlServerCredential.GetNetworkCredential().password)"
#$ConnectionString = "driver={SQL Server Native Client 11.0};server=$ComputerName;port=$Port;Trusted_Connection=yes;"
$Connection = [System.Data.Odbc.OdbcConnection]::new($ConnectionString)
$Connection.Open()

$Command = New-Object System.Data.Odbc.OdbcCommand($SelectQuery, $Connection)


$Dataset = New-Object system.Data.DataSet
$DataAdapter = New-Object system.Data.odbc.odbcDataAdapter($Command)
$RecordCount = $DataAdapter.fill($Dataset)
$Dataset.Tables
$Connection.close()


# Using System.Data.SqlClient (.NET Data Provider for SQL Server)
#$ConnectionString = "server=tcp:$ComputerName, $Port;Trusted_Connection=yes;"
$ConnectionString = "server=tcp:$ComputerName, $Port;Database=Futurama;User ID=$($SqlServerCredential.UserName);Password=$($SqlServerCredential.GetNetworkCredential().password);"
$Connection = [System.Data.SqlClient.SqlConnection]::new($ConnectionString)
$Connection.Open()

$Command = [System.Data.SqlClient.SqlCommand]::new($SelectQuery, $Connection)
#$DeleteCommand = [System.Data.SqlClient.SqlCommand]::new($DeleteQuery, $Connection)
#$DeleteCommand.ExecuteNonQuery()
#$InsertCommand = [System.Data.SqlClient.SqlCommand]::new($InsertQuery, $Connection)
#$InsertCommand.ExecuteNonQuery()


$Dataset = New-Object system.Data.DataSet
#$DataAdapter = New-Object system.Data.odbc.odbcDataAdapter($Command)
$DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)
$RecordCount = $DataAdapter.fill($Dataset)
$Dataset.Tables
$Connection.close()

# Using SqlServer module
#Install-Module -Name SqlServer
Import-Module sqlserver

Invoke-Sqlcmd -ServerInstance "tcp:$ComputerName" -Database Futurama -Query $SelectQuery -Username $SqlServerCredential.UserName -Password $SqlServerCredential.GetNetworkCredential().password



# dbatools
#Install-Module -Name dbatools
Import-Module -Name dbatools


Invoke-DbaQuery -SqlInstance $ComputerName -Query $SelectQuery -SqlCredential $SqlServerCredential 

# Create and use a db instance
$MyInstance = Connect-DbaInstance -SqlInstance $ComputerName -Credential $SqlServerCredential
$MyInstance.Query($SelectQuery)