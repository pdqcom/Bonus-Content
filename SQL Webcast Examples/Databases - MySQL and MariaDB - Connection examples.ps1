#  

#Add-Type -Path 'C:\Program Files (x86)\MySQL\MySQL Connector Net 6.9.10\Assemblies\v4.5\MySql.Data.dll'
Add-Type -Path 'C:\Program Files (x86)\MySQL\MySQL Connector Net 8.0.15\Assemblies\v4.5.2\MySql.Data.dll'

$MySqlCredential = Import-Clixml -Path '\\Server\Credentials\MySqlCred_web.xml'
$Server = 'S19-DB2-LAB'
$Port = '3306'

$DeleteQuery = @'
USE Futurama;
DELETE FROM Characters;
'@

$CreateQuery = @'
USE Futurama;
CREATE TABLE Characters (
	ID INT(11) NOT NULL AUTO_INCREMENT,
	Name VARCHAR(50) NOT NULL,
	PRIMARY KEY (ID)
);
'@

$InsertQuery = @'
USE Futurama;
INSERT INTO Characters (Name) 
VALUES 
    ('Fry'),
    ('Bender'),
    ('Leela'),
    ('Zapp'),
    ('Kiff'),
    ('Zoidberg')
'@

$SelectQuery = 'USE Futurama; SELECT * FROM Characters;'


# Using ExecuteReader() (etc) to get data

    $ConnectionString = "server=$Server;port=$Port;uid=$($MySqlCredential.UserName);pwd=$($MySqlCredential.GetNetworkCredential().password)"
    $Connection = [MySql.Data.MySqlClient.MySqlConnection]::new($ConnectionString)
    $Command = [MySql.Data.MySqlClient.MySqlCommand]::new($SelectQuery, $Connection)
    $Connection.Open()

    $reader = $Command.ExecuteReader()
    $DataTable = [System.Data.DataTable]::new()
    $DataTable.Load($reader)
    $DataTable

    $reader.Close()
    $Connection.Close()


# Using DataAdapter and DataSet's

    $ConnectionString = "server=$Server;port=$port;uid=$($MySqlCredential.UserName);pwd=$($MySqlCredential.GetNetworkCredential().password)"
    $Connection = [MySql.Data.MySqlClient.MySqlConnection]::new($ConnectionString)
    $Connection.Open()

    $Command = [MySql.Data.MySqlClient.MySqlCommand]::new()
    #$Command.CommandText = "SHOW DATABASES"
    $Command.CommandText = $SelectQuery
    $Command.Connection = $Connection

    $DataSet = [System.Data.DataSet]::new()
    $DataAdapter = [MySql.Data.MySqlClient.MySqlDataAdapter]::new($Command)
    
    
    $RecordCount = $DataAdapter.Fill($DataSet, "Characters")
    $DataSet.Tables["Characters"]

    $Connection.Close()


# Parameterized Queries


    # Query that is opened up for SQL Injection
        $UserInput = Read-Host "Please enter a name"
        $UnsafeSelectQuery = "USE Futurama; SELECT * FROM Characters WHERE Name = '$UserInput';"

        $ConnectionString = "server=$Server;port=$Port;uid=$($MySqlCredential.UserName);pwd=$($MySqlCredential.GetNetworkCredential().password)"
        $Connection = [MySql.Data.MySqlClient.MySqlConnection]::new($ConnectionString)
        $Connection.Open()

        $UnsafeCommand = [MySql.Data.MySqlClient.MySqlCommand]::new($UnsafeSelectQuery, $Connection)
        $DataSet = [System.Data.DataSet]::new()
        $DataAdapter = [MySql.Data.MySqlClient.MySqlDataAdapter]::new($UnsafeCommand)

        $RecordCount = $DataAdapter.Fill($DataSet, "Characters")
        $DataSet.Tables["Characters"]

        $Connection.Close()

    # Parameterized Query

        $UserInput = Read-Host "Please enter a name"
        $SelectQueryWithParameters = "USE Futurama; SELECT * FROM Characters WHERE Name = @SomethingFancy;"

        $ConnectionString = "server=$Server;port=$Port;uid=$($MySqlCredential.UserName);pwd=$($MySqlCredential.GetNetworkCredential().password)"
        $Connection = [MySql.Data.MySqlClient.MySqlConnection]::new($ConnectionString)
        $Connection.Open()

        $Command = [MySql.Data.MySqlClient.MySqlCommand]::new($SelectQueryWithParameters, $Connection)
        $Command.Parameters.AddWithValue("@SomethingFancy", "$UserInput") | Out-Null

        $DataSet = [System.Data.DataSet]::new()
        $DataAdapter = [MySql.Data.MySqlClient.MySqlDataAdapter]::new($Command)
    
    
        $recordcount = $DataAdapter.Fill($DataSet, "Characters")
        $DataSet.Tables["Characters"]

        $Connection.Close()