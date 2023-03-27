param (
    [string]$spnClientId,
    [string]$spnClientSecret,        
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$Azurelocation
)

$ArcJSDir = "C:\Jumpstart"
$ArcJSLogsDir = "$ArcJSDir\Logs"

# Change working directory 
Set-Location -Path $ArcJSDir

Start-Transcript -Path $ArcJSLogsDir\installArcAgentSQL.log
$ErrorActionPreference = 'SilentlyContinue'

# These settings will be replaced by the portal when the script is generated
$resourceTags= "Project=jumpstart_defender_sql_server"
$licenseType = "Paid"
$currentDir = Get-Location
$unattended = $spnClientId -And $spnTenantId -And $spnClientSecret

# These optional variables can be replaced with valid service principal details
# if you would like to use this script for a registration at scale scenario, i.e. run it on multiple machines remotely
# For more information, see https://docs.microsoft.com/sql/sql-server/azure-arc/connect-at-scale
#
# For security purposes, passwords should be stored in encrypted files as secure strings
#
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Host "Downloading AzureExtensionForSQLServer.msi"
	Invoke-WebRequest -Uri https://aka.ms/AzureExtensionForSQLServer -OutFile AzureExtensionForSQLServer.msi
    Write-Host "Download complete"
}
catch {
    Write-Host "Downloading AzureExtensionForSQLServer.msi failed."
    throw "Invoke-WebRequest failed: $_"
}

try {
    Write-Host "Installing AzureExtensionForSQLServer.msi"
	$exitcode = (Start-Process -FilePath msiexec.exe -ArgumentList @("/i", "AzureExtensionForSQLServer.msi","/l*v", "installationlog.txt", "/qn") -Wait -Passthru).ExitCode

	if ($exitcode -ne 0) {
		$message = "Installation failed: Please see $currentDir\installationlog.txt file for more information."
		Write-Host -ForegroundColor red $message
		return
	}

    Write-Host "Installing AzureExtensionForSQLServer.msi successful."

	if ($unattended) {
        Write-Host "Registering Arc-enabled SQL server using unattended method with AzureExtensionForSQLServer.exe."
		& "$env:ProgramW6432\AzureExtensionForSQLServer\AzureExtensionForSQLServer.exe" --subId $subscriptionId --resourceGroup $resourceGroup --location $Azurelocation --tenantid $spnTenantId --service-principal-app-id $spnClientId --service-principal-secret $spnClientSecret --licenseType $licenseType --tags $resourceTags 
	} else {
        Write-Host "Registering Arc-enabled SQL server using interactive login with AzureExtensionForSQLServer.exe"
		& "$env:ProgramW6432\AzureExtensionForSQLServer\AzureExtensionForSQLServer.exe" --subId $subscriptionId --resourceGroup $resourceGroup --location $Azurelocation --tenantid $spnTenantId --licenseType $licenseType  --tags $resourceTags
	}

	if($LASTEXITCODE -eq 0){
		Write-Host -ForegroundColor green "Azure extension for SQL Server is successfully installed. If one or more SQL Server instances are up and running on the server, Arc-enabled SQL Server instance resource(s) will be visible within a minute on the portal. Newly installed instances or instances started now will show within an hour."
	}
	else{
		$message = "Failed to install Azure extension for SQL Server. Please see $currentDir\AzureExtensionForSQLServerInstallation.log file for more information."
		Write-Host -ForegroundColor red $message
	}
}
catch {
	Write-Host -ForegroundColor red $_.Exception
	throw
}

Write-Host "SQL Server - Azure Arc resources should show up in resource group in less than 1 minute."
Write-Host "Arc-enabled SQL server deployment complete."

Stop-Transcript