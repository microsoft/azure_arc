@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Location for all resources')
param location string = resourceGroup().location

@maxLength(5)
@description('Random GUID')
param namingGuid string = toLower(substring(newGuid(), 0, 5))

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string = 'Ag-Workspace-${namingGuid}'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked the repo https://github.com/microsoft/jumpstart-agora-apps')
@minLength(1)
param githubUser string

@description('GitHub Personal access token for the user account')
@minLength(1)
@secure()
param githubPAT string

@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string = 'Ag-Vnet-Prod'

@description('Name of the Staging AKS subnet in the cloud virtual network')
param subnetNameCloudAksStaging string = 'Ag-Subnet-Staging'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloudAksInnerLoop string = 'Ag-Subnet-InnerLoop'

@description('Name of the storage queue')
param storageQueueName string = 'aioqueue'

@description('Name of the event hub')
param eventHubName string = 'aiohub${namingGuid}'

@description('Name of the event hub namespace')
param eventHubNamespaceName string = 'aiohubns${namingGuid}'

@description('Name of the event grid namespace')
param eventGridNamespaceName string = 'aioeventgridns${namingGuid}'

param akvName string = 'aioakv${namingGuid}'

@description('The name of the Azure Data Explorer Event Hub consumer group')
param eventHubConsumerGroupName string = 'cgadx${namingGuid}'

@description('The name of the Azure Data Explorer Event Hub production line consumer group')
param eventHubConsumerGroupNamePl string = 'cgadxpl${namingGuid}'

@description('Name of the storage account')
param aioStorageAccountName string = 'aiostg${namingGuid}'


@minLength(5)
@maxLength(50)
@description('Name of the Azure Container Registry')
param acrName string = 'agacr${namingGuid}'

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_ag/'

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

module networkDeployment 'mgmt/network.bicep' = {
  name: 'networkDeployment'
  params: {
    virtualNetworkNameCloud: virtualNetworkNameCloud
    subnetNameCloudAksStaging: subnetNameCloudAksStaging
    subnetNameCloudAksInnerLoop: subnetNameCloudAksInnerLoop
    deployBastion: deployBastion
    location: location
  }
}

module storageAccountDeployment 'mgmt/storageAccount.bicep' = {
  name: 'storageAccountDeployment'
  params: {
    location: location
  }
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    workspaceName: logAnalyticsWorkspaceName
    storageAccountName: storageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    deployBastion: deployBastion
    githubAccount: githubAccount
    githubBranch: githubBranch
    githubUser: githubUser
    githubPAT: githubPAT
    location: location
    subnetId: networkDeployment.outputs.innerLoopSubnetId
    acrName: acrName
    rdpPort: rdpPort
    namingGuid: namingGuid
  }
}

module eventHub 'data/eventHub.bicep' = {
  name: 'eventHub'
  params: {
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
    location: location
    eventHubConsumerGroupName: eventHubConsumerGroupName
    eventHubConsumerGroupNamePl: eventHubConsumerGroupNamePl
  }
}

module storageAccount 'storage/storageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    storageAccountName: aioStorageAccountName
    location: location
    storageQueueName: storageQueueName
  }
}

module eventGrid 'data/eventGrid.bicep' = {
  name: 'eventGrid'
  params: {
    eventGridNamespaceName: eventGridNamespaceName
    eventHubResourceId: eventHub.outputs.eventHubResourceId
    queueName: storageQueueName
    storageAccountResourceId: storageAccount.outputs.storageAccountId
    namingGuid: namingGuid
    location: location
  }
}

module keyVault 'data/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    tenantId: spnTenantId
    akvName: akvName
    location: location
  }
}

