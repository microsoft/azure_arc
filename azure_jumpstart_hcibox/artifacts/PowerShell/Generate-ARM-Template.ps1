$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Set paths
$Env:HCIBoxDir = "C:\HCIBox"

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile
Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Generate-ARM-Template.log"

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
$domainName = $HCIBoxConfig.SDNDomainFQDN.Split('.')
$ouPath = "OU=$($HCIBoxConfig.LCMADOUName)"
foreach ($name in $domainName) {
    $ouPath += ",DC=$name"
}

# Build DNS value
$dns = "[""" + $HCIBoxConfig.vmDNS + """]"

# Create keyvault name
$guid = ([System.Guid]::NewGuid()).ToString().subString(0,5).ToLower()
$keyVaultName = "hcibox-kv-" + $guid

# Set physical nodes
$physicalNodesSettings = "[ "
$storageAIPs = "[ "
$storageBIPs = "[ "
$count = 0
foreach ($node in $HCIBoxConfig.NodeHostConfig) {
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
$diagnosticsStorageName = "hciboxdiagsa$guid"

# Replace placeholder values in ARM template with real values
$hciParams = "$env:HCIBoxDir\hci.parameters.json"
(Get-Content -Path $hciParams) -replace 'clusterName-staging', $HCIBoxConfig.ClusterName | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'arcNodeResourceIds-staging', $arcNodeResourceIds | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'localAdminUserName-staging', 'Administrator' | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'localAdminPassword-staging', $($HCIBoxConfig.SDNAdminPassword) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'AzureStackLCMAdminUserName-staging', $($HCIBoxConfig.LCMDeployUsername) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'AzureStackLCMAdminAdminPassword-staging', $($HCIBoxConfig.SDNAdminPassword) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'arbDeploymentAppId-staging', $($env:spnClientId) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'arbDeploymentAppSecret-staging', $($env:spnClientSecret) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'arbDeploymentSPNObjectID-staging', $SPNobjectId | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'hciResourceProviderObjectID-staging', $env:spnProviderId | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'domainFqdn-staging', $($HCIBoxConfig.SDNDomainFQDN) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'namingPrefix-staging', $($HCIBoxConfig.LCMDeploymentPrefix) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'adouPath-staging', $ouPath | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'subnetMask-staging', $($HCIBoxConfig.rbSubnetMask) | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'defaultGateway-staging', $HCIBoxConfig.SDNLabRoute | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'startingIp-staging', $HCIBoxConfig.clusterIpRangeStart | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'endingIp-staging', $HCIBoxConfig.clusterIpRangeEnd | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'dnsServers-staging', $dns | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'keyVaultName-staging', $keyVaultName | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'physicalNodesSettings-staging', $physicalNodesSettings | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'ClusterWitnessStorageAccountName-staging', $env:stagingStorageAccountName | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'diagnosticStorageAccountName-staging', $diagnosticsStorageName | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'storageNicAVLAN-staging', $HCIBoxConfig.StorageAVLAN | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'storageNicBVLAN-staging', $HCIBoxConfig.StorageBVLAN | Set-Content -Path $hciParams
(Get-Content -Path $hciParams) -replace 'customLocation-staging', $HCIBoxConfig.rbCustomLocationName | Set-Content -Path $hciParams