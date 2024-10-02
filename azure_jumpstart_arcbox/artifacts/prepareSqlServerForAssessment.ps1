#  This script introduces some addtional SQL server features that are supported only on IaaS, some on both IaaS and SQL MI
Install-PackageProvider -Name NuGet -Force
Install-Module -Name SqlServer -AllowClobber -Force -Scope AllUsers
Import-Module -Name SqlServer -Force -PassThru

$sqlInstance = "MSSQLSERVER"

# Get the SQL Server instance
$managedComputer = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer

# Find the TCP/IP protocol
$serverProtocols = $managedComputer.ServerInstances[$sqlInstance].ServerProtocols

# find TCP protocol
$tcpProtocol = $serverProtocols | Where-Object { $_.Name -eq "TCP" }

# Enable TCP/IP protocol and apply changes
if ($tcpProtocol.IsEnabled -eq $false)
{
    $tcpProtocol.IsEnabled = $true
    $tcpProtocol.Alter()

    # Restart SQL service
    Restart-Service -Name $sqlInstance
}

# Enable FILESTREAM in configuration manager
# Create Filestream file storage location
$fsDirPath = "C:\sqlfilestream"
if (![System.IO.Directory]::Exists($fsDirPath)) {
    New-Item -Path $fsDirPath -ItemType Directory
}

$wmi = Get-WmiObject -Namespace "ROOT\Microsoft\SqlServer\ComputerManagement16" -Class FilestreamSettings | where {$_.InstanceName -eq $sqlInstance}
$wmi.EnableFilestream(2, $sqlInstance)
Get-Service -Name $sqlInstance | Restart-Service -Force

# Enable filestream access levels in the database
Invoke-Sqlcmd "EXEC sp_configure filestream_access_level, 2;" -TrustServerCertificate
Invoke-Sqlcmd "RECONFIGURE" -TrustServerCertificate

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

ALTER DATABASE ArchiveDB SET RECOVERY FULL;
GO

ALTER DATABASE AdventureWorksLT2022 SET RECOVERY FULL;
GO
"@

Invoke-Sqlcmd $sqlScriptToExecute -TrustServerCertificate

# Wait for the script to complete