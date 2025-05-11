$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:LocalBoxDir = "C:\LocalBox"

# Import Configuration Module
$LocalBoxConfig = Import-PowerShellDataFile -Path $Env:LocalBoxConfigFile
Start-Transcript -Path "$($LocalBoxConfig.Paths.LogsDir)\Generate-ARM-Template.log"

# Add necessary role assignments
# $ErrorActionPreference = "Continue"
# New-AzRoleAssignment -ObjectId $env:spnProviderId -RoleDefinitionName "Azure Connected Machine Resource Manager" -ResourceGroup $env:resourceGroup -ErrorAction Continue
# $ErrorActionPreference = "Stop"

$arcNodes = Get-AzConnectedMachine -ResourceGroup $env:resourceGroup
$arcNodeResourceIds = $arcNodes.Id | ConvertTo-Json -AsArray

# foreach ($machine in $arcNodes) {
#     $ErrorActionPreference = "Continue"
#     New-AzRoleAssignment -ObjectId $machine.IdentityPrincipalId -RoleDefinitionName "Key Vault Secrets User" -ResourceGroup $env:resourceGroup
#     New-AzRoleAssignment -ObjectId $machine.IdentityPrincipalId -RoleDefinitionName "Reader" -ResourceGroup $env:resourceGroup
#     New-AzRoleAssignment -ObjectId $machine.IdentityPrincipalId -RoleDefinitionName "Azure Stack HCI Device Management Role" -ResourceGroup $env:resourceGroup
#     New-AzRoleAssignment -ObjectId $machine.IdentityPrincipalId -RoleDefinitionName "Azure Connected Machine Resource Manager" -ResourceGroup $env:resourceGroup
#     $ErrorActionPreference = "Stop"
# }

# Convert user credentials to base64
$SPNobjectId=$(az ad sp show --id $env:spnClientId --query id -o tsv)

# Construct OU path
$domainName = $LocalBoxConfig.SDNDomainFQDN.Split('.')
$ouPath = "OU=$($LocalBoxConfig.LCMADOUName)"
foreach ($name in $domainName) {
    $ouPath += ",DC=$name"
}

# Build DNS value
$dns = "[""" + $LocalBoxConfig.vmDNS + """]"

# Create keyvault name
$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$keyVaultName = "localbox-kv-" + $guid

# Set physical nodes
$physicalNodesSettings = "[ "
$storageAIPs = "[ "
$storageBIPs = "[ "
$count = 0
foreach ($node in $LocalBoxConfig.NodeHostConfig) {
    if ($count -gt 0) {
        $physicalNodesSettings += ", "
        $storageAIPs += ", "
        $storageBIPs += ", "
    }
    $physicalNodesSettings += "{ ""name"": ""$($node.Hostname)"", ""ipv4Address"": ""$($node.IP.Split("/")[0])"" }"
    $count = $count + 1
}
$physicalNodesSettings += " ]"
$storageAIPs += " ]"
$storageBIPs += " ]"

# Create diagnostics storage account name
$diagnosticsStorageName = "localboxdiagsa$guid"

# Replace placeholder values in ARM template with real values
$AzLocalParams = "$env:LocalBoxDir\azlocal.parameters.json"
(Get-Content -Path $AzLocalParams) -replace 'clusterName-staging', $LocalBoxConfig.ClusterName | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'arcNodeResourceIds-staging', $arcNodeResourceIds | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'localAdminUserName-staging', 'Administrator' | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'localAdminPassword-staging', $($LocalBoxConfig.SDNAdminPassword) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'AzureStackLCMAdminUserName-staging', $($LocalBoxConfig.LCMDeployUsername) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'AzureStackLCMAdminAdminPassword-staging', $($LocalBoxConfig.SDNAdminPassword) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'arbDeploymentAppId-staging', $($env:spnClientId) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'arbDeploymentAppSecret-staging', $($env:spnClientSecret) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'arbDeploymentSPNObjectID-staging', $SPNobjectId | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'hciResourceProviderObjectID-staging', $env:spnProviderId | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'domainFqdn-staging', $($LocalBoxConfig.SDNDomainFQDN) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'namingPrefix-staging', $($LocalBoxConfig.LCMDeploymentPrefix) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'adouPath-staging', $ouPath | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'subnetMask-staging', $($LocalBoxConfig.rbSubnetMask) | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'defaultGateway-staging', $LocalBoxConfig.SDNLabRoute | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'startingIp-staging', $LocalBoxConfig.clusterIpRangeStart | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'endingIp-staging', $LocalBoxConfig.clusterIpRangeEnd | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'dnsServers-staging', $dns | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'keyVaultName-staging', $keyVaultName | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'physicalNodesSettings-staging', $physicalNodesSettings | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'ClusterWitnessStorageAccountName-staging', $env:stagingStorageAccountName | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'diagnosticStorageAccountName-staging', $diagnosticsStorageName | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'storageNicAVLAN-staging', $LocalBoxConfig.StorageAVLAN | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'storageNicBVLAN-staging', $LocalBoxConfig.StorageBVLAN | Set-Content -Path $AzLocalParams
(Get-Content -Path $AzLocalParams) -replace 'customLocation-staging', $LocalBoxConfig.rbCustomLocationName | Set-Content -Path $AzLocalParams