using './main.bicep'

param tenantId = 'f5aa5871-c718-4296-816a-a123e5c696ea'
param spnProviderId = '2f1cea6b-9c86-4448-a33e-d62cec63d2fc'
param windowsAdminUsername = 'arcdemo'
param windowsAdminPassword = 'Marwan!234'
param logAnalyticsWorkspaceName = 'LocalBox-Workspace'
param natDNS = '8.8.8.8'
param githubAccount = 'microsoft'
param githubBranch = 'main'
param deployBastion = false
param location = 'northeurope'
param azureLocalInstanceLocation = 'australiaeast'
param rdpPort = '3389'
param autoDeployClusterResource = true
param autoUpgradeClusterResource = false
param vmAutologon = true
param vmSize = 'Standard_E32s_v6'
param enableAzureSpotPricing = false
param governResourceTags = true
param tags = {
  Project: 'jumpstart_LocalBox'
}
