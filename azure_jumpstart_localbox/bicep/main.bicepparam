using './main.bicep'

param azureEnvironment = 'AzureUSGovernment'
param tenantId = '<your tenant id>'
param spnProviderId = '<your Microsoft.AzureStackHCI resource provider object id>'
param windowsAdminUsername = 'arcdemo'
param windowsAdminPassword = '<your password>'
param logAnalyticsWorkspaceName = 'LocalBox-Workspace'
param natDNS = '8.8.8.8'
param githubAccount = 'JimmyHarper'
param githubBranch = 'gov-mods'
param deployBastion = false
param location = 'usgovvirginia'
param azureLocalInstanceLocation = 'usgovvirginia'
param rdpPort = '3389'
param autoDeployClusterResource = true
param autoUpgradeClusterResource = false
param vmAutologon = true
param vmSize = 'Standard_E32as_v6'
param enableAzureSpotPricing = false
param governResourceTags = true
param tags = {
  Project: 'jumpstart_LocalBox'
}
