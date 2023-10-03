 # Download the package
 param (
    [string]$spnClientId,
    [string]$spnClientSecret,        
    [string]$spnTenantId,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$Azurelocation,
    [string]$vmName
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

try {
		Invoke-WebRequest -Uri https://aka.ms/AzureExtensionForSQLServer -OutFile AzureExtensionForSQLServer.msi
}
catch {
    throw "Invoke-WebRequest failed: $_"
}

try {
	$exitcode = (Start-Process -FilePath msiexec.exe -ArgumentList @("/i", "AzureExtensionForSQLServer.msi","/l*v", "installationlog.txt", "/qn") -Wait -Passthru).ExitCode

	if ($exitcode -ne 0) {
		$message = "Installation failed: Please see $currentDir\installationlog.txt file for more information."
		Write-Host -ForegroundColor red $message
		return
	}

    & "$env:ProgramW6432\AzureExtensionForSQLServer\AzureExtensionForSQLServer.exe" --subId $subscriptionId `
    --resourceGroup $resourceGroup --location $Azurelocation `
    --tenantid $spnTenantId --service-principal-app-id $spnClientId `
    --service-principal-secret $spnClientSecret --licenseType Paid  
	

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
 