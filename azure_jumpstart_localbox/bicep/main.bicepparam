using './main.bicep'

param tenantId = '35ec29a0-0d95-408a-af76-14a19ddd545e'
param spnProviderId = '9c89054b-e718-4255-b664-71a65ea8ae14'
param windowsAdminUsername = ''
param windowsAdminPassword = '' 
param logAnalyticsWorkspaceName = 'LocalBox-Workspace'
param natDNS = '8.8.8.8'
param githubAccount = ''
param githubBranch = ''
param deployBastion = true
param location = 'southcentralus'
param azureLocalInstanceLocation = 'southcentralus'
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
