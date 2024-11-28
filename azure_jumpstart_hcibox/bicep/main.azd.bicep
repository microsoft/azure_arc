@minLength(1)
@maxLength(77)
@description('Prefix for resource group, i.e. {name}-rg')
param envName string

@description('Azure service principal client id')
param spnClientId string = 'null'

@description('Azure service principal client secret')
@secure()
param spnClientSecret string = 'null'

@description('Azure AD tenant id for your service principal')
param spnTenantId string = 'null'

@description('Azure AD object id for your Microsoft.AzureStackHCI resource provider')
param spnProviderId string ='null'

@description('Username for Windows account')
param windowsAdminUsername string = 'arcdemo'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string = 'HCIBox-Workspace'

@description('Public DNS to use for the domain')
param natDNS string = '8.8.8.8'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Location to deploy resources')
@allowed(['eastus', 'westeurope', 'australiaeast'])
param location string

@description('Override default RDP port using this parameter. Default is 3389.')
param rdpPort string = '3389'

@description('Choice to enable automatic deployment of Azure Arc enabled HCI cluster resource after the client VM deployment is complete. Default is false.')
param autoDeployClusterResource bool = false

@description('Choice to enable automatic upgrade of Azure Arc enabled HCI cluster resource after the client VM deployment is complete. Only applicable when autoDeployClusterResource is true. Default is false.')
param autoUpgradeClusterResource bool = false

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_hcibox/'

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${envName}-rg'
  location: location
}

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  scope: rg
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

module networkDeployment 'network/network.bicep' = {
  name: 'networkDeployment'
  scope: rg
  params: {
    deployBastion: deployBastion
    location: location
  }
}

module storageAccountDeployment 'mgmt/storageAccount.bicep' = {
  name: 'stagingStorageAccountDeployment'
  scope: rg
  params: {
    location: location
  }
}

module hostDeployment 'host/host.bicep' = {
  name: 'hostVmDeployment'
  scope: rg
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    spnProviderId: spnProviderId
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: storageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    subnetId: networkDeployment.outputs.subnetId
    deployBastion: deployBastion
    natDNS: natDNS
    location: location
    rdpPort: rdpPort
    autoDeployClusterResource: autoDeployClusterResource
    autoUpgradeClusterResource: autoUpgradeClusterResource
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output RDP_PORT string = rdpPort
output AZURE_TENANT_ID string = tenant().tenantId
