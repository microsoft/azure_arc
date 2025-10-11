@description('Azure AD tenant id for your service principal')
param tenantId string

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

@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string = 'Ag-Vnet-Prod'

@description('Name of the Staging AKS subnet in the cloud virtual network')
param subnetNameCloudK3s string = 'Ag-Subnet-K3s'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloud string = 'Ag-Subnet-Cloud'

@description('Name of the storage queue')
param storageQueueName string = 'aioqueue'

@description('Name of the event hub')
param eventHubName string = 'aiohub${namingGuid}'

@description('Name of the event hub namespace')
param eventHubNamespaceName string = 'aiohubns${namingGuid}'

@description('Name of the Fabric Capacity')
param fabricCapacityName string = 'agfabric${namingGuid}'

@description('The administrator for the Microsoft Fabric capacity')
param fabricCapacityAdmin string

@description('Name of the storage account')
param aioStorageAccountName string = 'aiostg${namingGuid}'

@description('The custom location RPO ID')
param customLocationRPOID string

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Enable automatic logon into Virtual Machine')
param vmAutologon bool = true

@description('The agora scenario to be deployed')
param scenario string = 'contoso_hypermarket'

@description('The name of the Azure Arc K3s cluster')
param k3sArcDataClusterName string = 'Ag-K3s-Seattle-${namingGuid}'

@description('The name of the Azure Arc K3s data cluster')
param k3sArcClusterName string = 'Ag-K3s-Chicago-${namingGuid}'

@description('The name of the Key Vault for site 1')
param akvNameSite1 string = 'agakv1${namingGuid}'

@description('The name of the Key Vault for site 2')
param akvNameSite2 string = 'agakv2${namingGuid}'

@description('The capacity of the OpenAI Cognitive Services account')
param openAICapacity int = 10

@description('The array of OpenAI models to deploy')
param azureOpenAIModel object = {
    name: 'gpt-4o'
    version: '2024-05-13'
    apiVersion: '2024-08-01-preview'
}

@description('Name of the NAT Gateway')
param natGatewayName string = 'Ag-NatGateway-${namingGuid}'

// @description('Option to deploy GPU-enabled nodes for the K3s Worker nodes.')
// param deployGPUNodes bool = false

@description('The sku name of the K3s cluster worker nodes.')
@allowed([
  'Standard_D8s_v5'
  'Standard_NV6ads_A10_v5'
  'Standard_NV4as_v4'
])
param k8sWorkerNodesSku string = 'Standard_D8s_v5'
//param k8sWorkerNodesSku string = deployGPUNodes ? 'Standard_NV4as_v4' : 'Standard_D8s_v5'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_ag/'
var k3sClusterNodesCount = 2 // Number of nodes to deploy in the K3s cluster

var customerUsageAttributionDeploymentName = '71393591-614c-4cbc-add8-d69954f3c9ec'

module customerUsageAttribution 'mgmt/customerUsageAttribution.bicep' = {
  name: 'pid-${customerUsageAttributionDeploymentName}'
  params: {
  }
}
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
    subnetNameCloudK3s: subnetNameCloudK3s
    subnetNameCloud: subnetNameCloud
    deployBastion: deployBastion
    location: location
    natGatewayName: natGatewayName
  }
}

module storageAccountDeployment 'mgmt/storageAccount.bicep' = {
  name: 'storageAccountDeployment'
  params: {
    location: location
  }
}

module ubuntuRancherK3sDataSvcDeployment 'kubernetes/ubuntuRancher.bicep' = {
  name: 'ubuntuRancherK3s2Deployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(storageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: networkDeployment.outputs.k3sSubnetId
    azureLocation: location
    vmName : k3sArcDataClusterName
    storageContainerName: toLower(k3sArcDataClusterName)
    namingGuid: namingGuid
  }
}

module ubuntuRancherK3sDeployment 'kubernetes/ubuntuRancher.bicep' = {
  name: 'ubuntuRancherK3sDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(storageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: networkDeployment.outputs.k3sSubnetId
    azureLocation: location
    vmName : k3sArcClusterName
    storageContainerName: toLower(k3sArcClusterName)
    namingGuid: namingGuid
  }
}

module ubuntuRancherK3sDataSvcNodesDeployment 'kubernetes/ubuntuRancherNodes.bicep' = [for i in range(0, k3sClusterNodesCount): {
  name: 'ubuntuRancherK3sNodesDeployment-${i}'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(storageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: networkDeployment.outputs.k3sSubnetId
    azureLocation: location
    vmName : '${k3sArcDataClusterName}-Node-0${i}'
    storageContainerName: toLower(k3sArcDataClusterName)
    namingGuid: namingGuid
    //deployGPUNodes: deployGPUNodes
    k8sWorkerNodesSku: k8sWorkerNodesSku
  }
  dependsOn: [
    ubuntuRancherK3sDataSvcDeployment
  ]
}]

module ubuntuRancherK3sNodesDeployment 'kubernetes/ubuntuRancherNodes.bicep' = [for i in range(0, k3sClusterNodesCount): {
  name: 'ubuntuRancherK3sNodes2Deployment-${i}'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(storageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: networkDeployment.outputs.k3sSubnetId
    azureLocation: location
    vmName : '${k3sArcClusterName}-Node-0${i}'
    storageContainerName: toLower(k3sArcClusterName)
    namingGuid: namingGuid
    //deployGPUNodes: deployGPUNodes
    k8sWorkerNodesSku: k8sWorkerNodesSku
  }
  dependsOn: [
    ubuntuRancherK3sDeployment
  ]
}]

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  dependsOn: [
    ubuntuRancherK3sNodesDeployment
    ubuntuRancherK3sDataSvcNodesDeployment
  ]
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    tenantId: tenantId
    workspaceName: logAnalyticsWorkspaceName
    storageAccountName: storageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    deployBastion: deployBastion
    githubAccount: githubAccount
    githubBranch: githubBranch
    location: location
    subnetId: networkDeployment.outputs.cloudSubnetId
    rdpPort: rdpPort
    namingGuid: namingGuid
    scenario: scenario
    customLocationRPOID: customLocationRPOID
    k3sArcClusterName: k3sArcClusterName
    k3sArcDataClusterName: k3sArcDataClusterName
    vmAutologon: vmAutologon
    openAIEndpoint: azureOpenAI.outputs.openAIEndpoint
    speachToTextEndpoint: azureOpenAI.outputs.speechToTextEndpoint
    azureOpenAIModel: azureOpenAIModel
    openAIDeploymentName: azureOpenAI.outputs.openAIDeploymentName
  }
}
module keyVault 'data/keyVault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    tenantId: tenantId
    akvNameSite1: akvNameSite1
    akvNameSite2: akvNameSite2
    location: location
  }
}

module storageAccount 'storage/storageAccount.bicep' = {
  name: 'aioStorageAccountDeployment'
  params: {
    storageAccountName: aioStorageAccountName
    location: location
    storageQueueName: storageQueueName
  }
}

module eventHub 'data/eventHub.bicep' = {
  name: 'eventHubDeployment'
  params: {
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
    location: location
  }
}

module fabricCapacity 'data/fabric.bicep' = if (!empty(fabricCapacityAdmin)) {
  name: 'fabricCapacity'
  params: {
    fabricCapacityName: fabricCapacityName
    fabricCapacityAdmin: fabricCapacityAdmin
  }
}

module azureOpenAI 'ai/aoai.bicep' = {
  name: 'azureOpenAIDeployment'
  params: {
    location: location
    openAIAccountName: 'openai${namingGuid}'
    azureOpenAIModel: azureOpenAIModel
    openAICapacity: openAICapacity
  }
}
