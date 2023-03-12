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
    Write-Host "Onboarding $remoteSQLServerName server to Azure Arc."

    # Copy MSI on remote SQL server
    Write-Host "Copying $msiSourceFile on remote server."
    Copy-VMFile $remoteSQLServerName -SourcePath $msiSourceFile -DestinationPath $msiSourceFile -CreateFullPath -FileSource Host -Force
    Write-Host "$msiSourceFile file copied on remote server."
    
    # Remote execute MSI on remote SQL server
    Write-Host "Installing $msiSourceFile file on remote server."
    Invoke-Command -VMName $remoteSQLServerName -ScriptBlock {Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $Using:msiSourceFile /quiet /qn /L*V installation.log" -Wait -PassThru} -Credential $winCreds    
    Write-Host "Installed $msiSourceFile file on remote server."
    
    # Remote execute Arc-enabled SQL server extension
    Write-Host "Installing Arc-enabled SQL Server extension on remote server."
    Invoke-Command -VMName $remoteSQLServerName -ScriptBlock {& "$env:ProgramW6432\AzureExtensionForSQLServer\AzureExtensionForSQLServer.exe" --subId $Using:subscriptionId --resourceGroup $Using:resourceGroup --location $Using:azureRegion --tenantid $Using:servicePrincipalTenantId --service-principal-app-id $Using:servicePrincipalAppId --service-principal-secret $Using:servicePrincipalSecret --licenseType $Using:licenseType} -Credential $winCreds
    Write-Host "Installed Arc-enabled SQL Server extension on remote server $remoteSQLServerName"
}
