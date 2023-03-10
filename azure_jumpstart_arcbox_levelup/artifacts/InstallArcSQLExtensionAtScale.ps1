param (
    [string]$remoteWindowsAdminUsername = "Administrator",
    [SecureString]$remoteWindowsAdminPassword,
    [string]$servicePrincipalAppId = $Env:spnClientID,
    [string]$servicePrincipalSecret = $Env:spnClientSecret,
    [string]$servicePrincipalTenantId = $Env:spnTenantId,
    [string]$subscriptionId = $Env:subscriptionId,
    [string]$resourceGroup = $Env:resourceGroup,
    [string]$azureRegion = $Env:azureLocation,
    [string[]]$remoteSQLServerList = "JSLU-Win-SQL-02, JSLU-Win-SQL-03",
    [string]$licenseType = "PAYG",
    [string]$AzureArcDir = "C:\ArcBoxLevelup"
)

# Download MSI into a local folder
foreach ($remoteSQLServerName in $remoteSQLServerList)
{
    $SqlExtensionMsi = "AzureExtensionForSQLServer.msi"
    Invoke-WebRequest "https://aka.ms/AzureExtensionForSQLServer/test" -OutFile "${AzureArcDir}\${SqlExtensionMsi}"
    
    # Create Windows credential object
    $winCreds = New-Object System.Management.Automation.PSCredential ($remoteWindowsAdminUsername, $remoteWindowsAdminPassword)
    
    # Copy MSI on remote SQL server
    Copy-VMFile $remoteSQLServerName -SourcePath "${AzureArcDir}\${SqlExtensionMsi}" -DestinationPath "${AzureArcDir}\${SqlExtensionMsi}" -CreateFullPath -FileSource Host
    
    # Remote execute MSI on remote SQL server
    $command = "msiexec.exe /i ${AzureArcDir}\${SqlExtensionMsi}"
    $scriptblock = [Scriptblock]::Create($command)
    Invoke-Command -VMName $remoteSQLServerName -ScriptBlock $scriptblock -Credential $winCreds
    
    # Remote execute Arc-enabled SQL server extension
    Invoke-Command -VMName $remoteSQLServerName -ScriptBlock {&"$env:ProgramW6432\AzureExtensionForSQLServer\AzureExtensionForSQLServer.exe" --subId $Using:subscriptionId --resourceGroup $Using:resourceGroup --location $Using:azureRegion --tenantid $Using:servicePrincipalTenantId --service-principal-app-id $Using:servicePrincipalAppId --service-principal-secret $Using:servicePrincipalSecret --licenseType $Using:licenseType} -Credential $winCreds --waitTime 5
}

