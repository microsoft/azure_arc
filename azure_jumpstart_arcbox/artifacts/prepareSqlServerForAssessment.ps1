#  This script introduces some addtional SQL server features that are supported only on IaaS, some on both IaaS and SQL MI
# Enable FILESTREAM in configuration manager

# Create Filestream file storage location
$fsDirPath = "C:\sqlfilestream"
if (![System.IO.Directory]::Exists($fsDirPath)) {
    New-Item -Path $fsDirPath -ItemType Directory
}

$sqlInstance = "MSSQLSERVER"
$wmi = Get-WmiObject -Namespace "ROOT\Microsoft\SqlServer\ComputerManagement15" -Class FilestreamSettings | where {$_.InstanceName -eq $sqlInstance}
$wmi.EnableFilestream(2, $sqlInstance)
Get-Service -Name $sqlInstance | Restart-Service -Force

# Enable filestream access levels in the database
Set-ExecutionPolicy RemoteSigned -Force
Import-Module "sqlps" -DisableNameChecking
Invoke-Sqlcmd "EXEC sp_configure filestream_access_level, 2;"
Invoke-Sqlcmd "RECONFIGURE"

# Create Archive database to introduce these SQL feature usage
# Create sample database
$sqlScriptToExecute = @"
DROP DATABASE IF EXISTS [ArchiveDB]
GO

CREATE DATABASE ArchiveDB 
ON
PRIMARY ( NAME = Arch1,
    FILENAME = '$fsDirPath\ArchiveDB.mdf'),
FILEGROUP FileStreamGroup1 CONTAINS FILESTREAM ( NAME = Arch3,
    FILENAME = '$fsDirPath\filestream1')
LOG ON  ( NAME = Archlog1,
    FILENAME = '$fsDirPath\archlog1.ldf')
GO

CREATE TABLE ArchiveDB.dbo.Records
(
    [Id] [uniqueidentifier] ROWGUIDCOL NOT NULL UNIQUE, 
    [SerialNumber] INTEGER UNIQUE,
    [Chart] VARBINARY(MAX) FILESTREAM NULL
);
GO
"@

Invoke-Sqlcmd $sqlScriptToExecute

# Wait for the script to complete