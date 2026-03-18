using './main.bicep'

param tenantId = '<ede7f777-8472-4ae1-ab7a-3e85f44bfe06>'
param spnProviderId = '<2c6ff338-dd0a-46a0-bd61-53655819369c>'
param windowsAdminUsername = 'Abdelrahman'
param windowsAdminPassword = '<Microsoft@244f>'
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
