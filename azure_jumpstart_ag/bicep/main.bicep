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
param namingGuid string = toLower(substring(newGuid(),0,5))

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
param logAnalyticsWorkspaceName string = 'Ag-Workspace'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'jumpstart_ag'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked https://github.com/microsoft/azure-arc-jumpstart-apps')
param githubUser string = 'microsoft'

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

@minLength(5)
@maxLength(50)
@description('Name of the production Azure Container Registry')
param acrNameProd string = 'Agacrprod${namingGuid}'

@minLength(5)
@maxLength(50)
@description('Name of the dev Azure Container Registry')
param acrNameStaging string = 'AgacrStaging${namingGuid}'

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
    virtualNetworkNameCloud : virtualNetworkNameCloud
    subnetNameCloudAksStaging: subnetNameCloudAksStaging
    subnetNameCloudAksInnerLoop : subnetNameCloudAksInnerLoop
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

module kubernetesDeployment 'kubernetes/aks.bicep' = {
  name: 'kubernetesDeployment'
  params: {
    aksStagingClusterName: aksStagingClusterName
    virtualNetworkNameCloud : networkDeployment.outputs.virtualNetworkNameCloud
    aksSubnetNameStaging : subnetNameCloudAksStaging
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    location: location
    sshRSAPublicKey: sshRSAPublicKey
    acrNameStaging: acrNameStaging
    acrNameProd: acrNameProd
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
    location: location
    subnetId: networkDeployment.outputs.innerLoopSubnetId
    aksStagingClusterName: aksStagingClusterName
    iotHubHostName: iotHubDeployment.outputs.iotHubHostName
    acrNameStaging: kubernetesDeployment.outputs.acrStagingName
    acrNameProd: 'acrprod' // kubernetesDeployment.outputs.acrProdName
    rdpPort: rdpPort
  }
}

module iotHubDeployment 'data/iotHub.bicep' = {
  name: 'iotHubDeployment'
  params: {
    location: location
    iotHubName: iotHubName
  }
}

module adxDeployment 'data/dataExplorer.bicep' = {
  name: 'adxDeployment'
  params: {
    location: location
    namingGuid : namingGuid
    iotHubId : iotHubDeployment.outputs.iotHubId
    iotHubConsumerGroup: iotHubDeployment.outputs.iotHubConsumerGroup
  }
}

module cosmosDBDeployment 'data/cosmosDB.bicep' = {
  name: 'cosmosDBADeployment'
  params: {
    location: location
    accountName: accountName
  }
}
