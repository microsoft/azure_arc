param (
    [string]$remoteWindowsAdminUsername = "Administrator",
    [SecureString]$remoteWindowsAdminPassword,
    [string]$servicePrincipalAppId = $Env:spnClientID,
    [string]$servicePrincipalSecret = $Env:spnClientSecret,
    [string]$servicePrincipalTenantId = $Env:spnTenantId,
    [string]$subscriptionId = $Env:subscriptionId,
    [string]$resourceGroup = $Env:resourceGroup,
    [string]$azureRegion = $Env:azureLocation,
    [string[]]$remoteSQLServerList = [string[]]("JSLU-Win-SQL-02", "JSLU-Win-SQL-03"),
    [string]$licenseType = "PAYG",
    [string]$AzureArcDir = "C:\ArcBoxLevelup"
)

# $secWindowsPassword = ConvertTo-SecureString "ArcDemo123!!" -AsPlainText -Force 
# .\InstallArcSQLExtensionAtScale.ps1 -remoteWindowsAdminPassword $secWindowsPassword

# Download MSI into a local folder
$msiSourceFile = "${AzureArcDir}\AzureExtensionForSQLServer.msi"

Invoke-WebRequest "https://aka.ms/AzureExtensionForSQLServer/test" -OutFile $msiSourceFile

# Iterate through list of servers and onboard to Azur Arc
# Create Windows credential object
$winCreds = New-Object System.Management.Automation.PSCredential ($remoteWindowsAdminUsername, $remoteWindowsAdminPassword)
    
foreach ($remoteSQLServerName in $remoteSQLServerList)
{
    
    # Copy MSI on remote SQL server
    Copy-VMFile $remoteSQLServerName -SourcePath $msiSourceFile -DestinationPath $msiSourceFile -CreateFullPath -FileSource Host -Force
    
    # Remote execute MSI on remote SQL server
    $command = "msiexec.exe /i $msiSourceFile"
    $scriptblock = [Scriptblock]::Create($command)
    Invoke-Command -VMName $remoteSQLServerName -ScriptBlock $scriptblock -Credential $winCreds
    
    # Remote execute Arc-enabled SQL server extension
    Invoke-Command -VMName $remoteSQLServerName -ScriptBlock {&"$env:ProgramW6432\AzureExtensionForSQLServer\AzureExtensionForSQLServer.exe" --subId $Using:subscriptionId --resourceGroup $Using:resourceGroup --location $Using:azureRegion --tenantid $Using:servicePrincipalTenantId --service-principal-app-id $Using:servicePrincipalAppId --service-principal-secret $Using:servicePrincipalSecret --licenseType $Using:licenseType --waitTime 5} -Credential $winCreds
}
