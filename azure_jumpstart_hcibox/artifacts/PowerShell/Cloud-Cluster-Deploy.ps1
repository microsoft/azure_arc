$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Cloud-Cluster-Deploy.log"

# Connect to Azure
Write-Host 'Creating credentials and connecting to Azure'
$azureAppCred = (New-Object System.Management.Automation.PSCredential $env:spnClientID, (ConvertTo-SecureString -String $env:spnClientSecret -AsPlainText -Force))
Connect-AzAccount -ServicePrincipal -Subscription $env:subscriptionId -Tenant $env:spnTenantId -Credential $azureAppCred

# Install some modules
Install-Module -Name Az.Resources -Force
Install-Module Az.ConnectedMachine -Force
Import-Module -Name Az.Resources, Az.ConnectedMachine -Force

# Add necessary role assignments 
New-AzRoleAssignment -ApplicationId $env:spnClientId -RoleDefinitionName "Key Vault Administrator" -ResourceGroup $env:resourceGroup
New-AzRoleAssignment -ObjectId $env:spnProviderId -RoleDefinitionName "Azure Connected Machine Resource Manager" -ResourceGroup $env:resourceGroup -ErrorAction SilentlyContinue

$arcNodes = Get-AzConnectedMachine -ResourceGroup $env:resourceGroup
$arcNodeResourceIds = "["
$count = 0
foreach ($machine in $arcNodes) {
    New-AzRoleAssignment -ObjectId $machine.IdentityPrincipalId -RoleDefinitionName "Key Vault Secrets User" -ResourceGroup $env:resourceGroup
    if ($count -gt 0) {
        $arcNodeResourceIds += ", "
    }
    $arcNodeResourceIds += """" + $machine.id + """"
    $count = $count + 1
}
$arcNodeResourceIds += "]"

# Get storage account key and convert to base 64
$saKeys = Get-AzStorageAccountKey -ResourceGroupName $env:resourceGroup -Name $env:stagingStorageAccountName
$storageAccountAccessKey =  [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($saKeys[0].value))
 
# Convert user credentials to base 64 
$AzureStackLCM=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($HCIBoxConfig.LCMDeployUsername):$($HCIBoxConfig.SDNAdminPassword)"))
$LocalUser=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("Administrator:$($HCIBoxConfig.SDNAdminPassword)"))
$AzureSPN=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($env:spnClientId):$($env:spnClientSecret)"))

# Construct OU path
$domainName = $HCIBoxConfig.SDNDomainFQDN.Split('.')
$ouPath = "OU=$($HCIBoxConfig.LCMADOUName)"
foreach ($name in $domainName) {
    $ouPath += ",DC=$name"
}

# Build DNS value
$dns = "[""" + $HCIBoxConfig.rbDNSIP + """]"

# Create keyvault name
$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$keyVaultName = "hcibox-kv-" + $guid
$secretsLocation = "https://$keyVaultName.vault.azure.net"

# Set physical nodes
$physicalNodesSettings = "[ "
$count = 0
foreach ($node in $HCIBoxConfig.NodeHostConfig) {
    if ($count -gt 0) {
        $physicalNodesSettings += ", "
    }
    $physicalNodesSettings += "{ ""name"": ""$($node.Hostname)"", ""ipv4Address"": ""$($node.IP.Split("/")[0])"" }"
    $count = $count + 1
}
$physicalNodesSettings += " ]"

# Create diagnostics storage account name
$diagnosticsStorageName = "hciboxdiagsa$guid"

# Replace placeholder values in ARM template with real values
$hciParams = "$env:HCIBoxDir\hci.parameters.json"
(Get-Content -Path $hciParams) -replace 'arcNodeResourceIds-staging', $arcNodeResourceIds | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'localAdminSecretValue-staging', $LocalUser | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'domainAdminSecretValue-staging', $AzureStackLCM | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'arbDeploymentSpnValue-staging', $AzureSPN | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'storageWitnessValue-staging', $storageAccountAccessKey | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'domainFqdn-staging', $($HCIBoxConfig.SDNDomainFQDN) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'namingPrefix-staging', $($HCIBoxConfig.LCMDeploymentPrefix) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'adouPath-staging', $ouPath | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'subnetMask-staging', $($HCIBoxConfig.rbSubnetMask) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'defaultGateway-staging', $HCIBoxConfig.AKSGWIP | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'startingIp-staging', $HCIBoxConfig.AKSNodeStartIP | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'endingIp-staging', $HCIBoxConfig.AKSNodeEndIP | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'dnsServers-staging', $dns | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'keyVaultName-staging', $keyVaultName | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'secretsLocation-staging', $secretsLocation | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'physicalNodesSettings-staging', $physicalNodesSettings | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'ClusterWitnessStorageAccountName-staging', $env:stagingStorageAccountName | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'diagnosticStorageAccountName-staging', $diagnosticsStorageName | Set-Content -Path $hciParams

