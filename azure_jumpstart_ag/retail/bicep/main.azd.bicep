@description('Azure service principal client id')
param spnClientId string = ''

@description('Azure service principal client secret')
@minLength(12)
@maxLength(123)
@secure()
param spnClientSecret string = newGuid()

@description('Azure AD tenant id for your service principal')
param spnTenantId string = ''

@minLength(1)
@maxLength(77)
@description('Prefix for resource group, i.e. {name}-rg')
param envName string = toLower(substring(newGuid(), 0, 5))

@description('Location for all resources')
param location string = ''

@maxLength(5)
@description('Random GUID')
param namingGuid string = toLower(substring(newGuid(), 0, 5))

@description('Username for Windows account')
param windowsAdminUsername string = ''

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string = newGuid()

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string = ''

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
param githubUser string  = 'sampleUser'

@description('GitHub Personal access token for the user account')
@minLength(1)
@secure()
param githubPAT string = newGuid()

@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string = 'Ag-Vnet-Prod'

@description('Name of the Staging AKS subnet in the cloud virtual network')
param subnetNameCloudAksStaging string = 'Ag-Subnet-Staging'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloudAksInnerLoop string = 'Ag-Subnet-InnerLoop'

@description('The name of the Staging Kubernetes cluster resource')
param aksStagingClusterName string = 'Ag-AKS-Staging'

@description('The name of the IotHub')
param iotHubName string = 'Ag-IotHub-${namingGuid}'

@description('The name of the Cosmos DB account')
param accountName string = 'agcosmos${namingGuid}'

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string = 'agadx${namingGuid}'

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string = 'Orders'

@minLength(5)
@maxLength(50)
@description('Name of the Azure Container Registry')
param acrName string = 'agacr${namingGuid}'

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_ag/retail/'

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

module networkDeployment 'mgmt/network.bicep' = {
  name: 'networkDeployment'
  scope: rg
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
  scope: rg
  params: {
    location: location
  }
}

module kubernetesDeployment 'kubernetes/aks.bicep' = {
  name: 'kubernetesDeployment'
  scope: rg
  params: {
    aksStagingClusterName: aksStagingClusterName
    virtualNetworkNameCloud: networkDeployment.outputs.virtualNetworkNameCloud
    aksSubnetNameStaging: subnetNameCloudAksStaging
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    location: location
    acrName: acrName
    sshRSAPublicKey: sshRSAPublicKey
  }
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  scope: rg
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
    aksStagingClusterName: aksStagingClusterName
    iotHubHostName: iotHubDeployment.outputs.iotHubHostName
    cosmosDBName: accountName
    cosmosDBEndpoint: cosmosDBDeployment.outputs.cosmosDBEndpoint
    acrName: acrName
    rdpPort: rdpPort
    adxClusterName: adxClusterName
    namingGuid: namingGuid
  }
}

module iotHubDeployment 'data/iotHub.bicep' = {
  name: 'iotHubDeployment'
  scope: rg
  params: {
    location: location
    iotHubName: iotHubName
  }
}

module adxDeployment 'data/dataExplorer.bicep' = {
  name: 'adxDeployment'
  scope: rg
  params: {
    location: location
    adxClusterName: adxClusterName
    iotHubId: iotHubDeployment.outputs.iotHubId
    iotHubConsumerGroup: iotHubDeployment.outputs.iotHubConsumerGroup
    cosmosDBAccountName: accountName
    posOrdersDBName: posOrdersDBName
  }
}

module cosmosDBDeployment 'data/cosmosDB.bicep' = {
  name: 'cosmosDBDeployment'
  scope: rg
  params: {
    location: location
    accountName: accountName
    posOrdersDBName: posOrdersDBName
  }
}

output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output NAMING_GUID string = namingGuid
output RDP_PORT string = rdpPort

output ADX_CLUSTER_NAME string = adxClusterName
output IOT_HUB_NAME string = iotHubName
output COSMOS_DB_NAME string = accountName
output ACR_NAME string = acrName
