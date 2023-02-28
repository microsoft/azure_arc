@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Location for all resources')
param location string = resourceGroup().location

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
param virtualNetworkNameCloud string = 'Ag-Cloud-VNet'

@description('Name of the Cloud VNet')
param virtualNetworkNameStores string = 'Ag-Stores-VNet'

@description('Name of the prod AKS subnet in the cloud virtual network')
param subnetNameCloudAksProd string = 'Ag-Cloud-Prod-Subnet'

@description('Name of the dev AKS subnet in the cloud virtual network')
param subnetNameCloudAksDev string = 'Ag-Cloud-Dev-Subnet'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloudAksInnerLoop string = 'Ag-Cloud-inner-loop-Subnet'

@description('Name of the New York subnet subnet in the stores virtual network')
param subnetNameStoresNewYork string = 'Ag-Store-NewYork-Subnet'

@description('Name of the Chicago subnet subnet in the stores virtual network')
param subnetNameStoresChicago string = 'Ag-Store-Chicago-Subnet'

@description('Name of the Boston subnet subnet in the stores virtual network')
param subnetNameStoresBoston string = 'Ag-Store-Boston-Subnet'

@description('The name of the Prod Kubernetes cluster resource')
param aksProdClusterName string = 'Ag-AKS-Prod'

@description('The name of the Dev Kubernetes cluster resource')
param aksDevClusterName string = 'Ag-AKS-Dev'

@description('The name of the synapse workspace')
param synapseWorkspaceName string = 'agsynapse-${namingGuid}'

@description('The name of the IotHub')
param iotHubName string = 'Ag-IotHub-${namingGuid}'

@minLength(5)
@maxLength(50)
@description('Name of the production Azure Container Registry')
param acrNameProd string = 'Agacrprod${namingGuid}'

@minLength(5)
@maxLength(50)
@description('Name of the dev Azure Container Registry')
param acrNameDev string = 'Agacrdev${namingGuid}'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_ag/'

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

module networkDeployment 'network/network.bicep' = {
  name: 'networkDeployment'
  params: {
    virtualNetworkNameCloud : virtualNetworkNameCloud
    subnetNameCloudAksProd : subnetNameCloudAksProd
    subnetNameCloudAksDev: subnetNameCloudAksDev
    subnetNameCloudAksInnerLoop : subnetNameCloudAksInnerLoop
    subnetNameStoresNewYork: subnetNameStoresNewYork
    subnetNameStoresChicago: subnetNameStoresChicago
    subnetNameStoresBoston: subnetNameStoresBoston
    virtualNetworkNameStores: virtualNetworkNameStores
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

module kubernestesDeployment 'kubernetes/aks.bicep' = {
  name: 'kubernetesDeployment'
  params: {
    aksProdClusterName: aksProdClusterName
    aksDevClusterName: aksDevClusterName
    virtualNetworkNameCloud : networkDeployment.outputs.virtualNetworkNameCloud
    aksSubnetNameProd : subnetNameCloudAksProd
    aksSubnetNameDev : subnetNameCloudAksDev
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    location: location
    sshRSAPublicKey: sshRSAPublicKey
    acrNameDev: acrNameDev
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
    githubUser: githubUser
    location: location
    subnetId: networkDeployment.outputs.innerLoopSubnetId
    aksProdClusterName : aksProdClusterName
    aksDevClusterName : aksDevClusterName
    iotHubHostName : iotHubDeployment.outputs.iotHubHostName
    acrNameDev : kubernestesDeployment.outputs.acrDevName
    acrNameProd : kubernestesDeployment.outputs.acrProdName
  }
}

/*module synapseDeployment 'mgmt/synapse.bicep' = {
  name: 'synapseDeployment'
  params: {
    synapseWorkspaceName: synapseWorkspaceName
    location: location
    synapseAdminUserName : windowsAdminUsername
    synapseAdminPassword : windowsAdminPassword
    namingGuid : namingGuid
    iotHubId : iotHubDeployment.outputs.iotHubId
    iotHubConsumerGroup: iotHubDeployment.outputs.iotHubConsumerGroup
  }
}*/

module iotHubDeployment 'mgmt/iotHub.bicep' = {
  name: 'iotHubDeployment'
  params: {
    location: location
    iotHubName: iotHubName
  }
}
