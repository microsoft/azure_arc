@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Azure service principal object id')
param spnObjectId string

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
param githubBranch string = 'agora_2.0'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string = 'Ag-Vnet-Prod'

@description('Name of the Staging AKS subnet in the cloud virtual network')
param subnetNameCloudK3s string = 'Ag-Subnet-K3s'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloud string = 'Ag-Subnet-Cloud'

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string = 'agadx${namingGuid}'

@description('Name of the storage queue')
param storageQueueName string = 'aioqueue'

@description('Name of the event hub')
param eventHubName string = 'aiohub${namingGuid}'

@description('Name of the event hub namespace')
param eventHubNamespaceName string = 'aiohubns${namingGuid}'

@description('Name of the event grid namespace')
param eventGridNamespaceName string = 'aioeventgridns${namingGuid}'

@description('Name of the storage account')
param aioStorageAccountName string = 'aiostg${namingGuid}'

@description('The name of the Azure Data Explorer Event Hub consumer group for assemblybatteries')
param stagingDataCGName string = 'mqttdataemulator'

@description('The name of ESA container in Storage Account')
param stcontainerName string = 'esacontainer'

@description('The custom location RPO ID')
param customLocationRPOID string

@minLength(5)
@maxLength(50)
@description('Name of the Azure Container Registry')
param acrName string = 'agacr${namingGuid}'

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

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

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_ag/'
var k3sClusterNodesCount = 2 // Number of nodes to deploy in the K3s cluster

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
  }
}

module storageAccountDeployment 'mgmt/storageAccount.bicep' = {
  name: 'storageAccountDeployment'
  params: {
    location: location
    spnObjectId: spnObjectId
  }
}

module ubuntuRancherK3sDataSvcDeployment 'kubernetes/ubuntuRancher.bicep' = {
  name: 'ubuntuRancherK3sDataSvcDeployment'
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
  name: 'ubuntuRancherK3sDataSvcNodesDeployment-${i}'
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
  }
  dependsOn: [
    ubuntuRancherK3sDataSvcDeployment
  ]
}]

module ubuntuRancherK3sNodesDeployment 'kubernetes/ubuntuRancherNodes.bicep' = [for i in range(0, k3sClusterNodesCount): {
  name: 'ubuntuRancherK3sNodesDeployment-${i}'
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
  }
  dependsOn: [
    ubuntuRancherK3sDeployment
  ]
}]

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
    location: location
    subnetId: networkDeployment.outputs.cloudSubnetId
    acrName: acrName
    rdpPort: rdpPort
    adxClusterName: adxClusterName
    namingGuid: namingGuid
    scenario: scenario
    customLocationRPOID: customLocationRPOID
    spnObjectId: spnObjectId
    stcontainerName: stcontainerName
    k3sArcClusterName: k3sArcClusterName
    k3sArcDataClusterName: k3sArcDataClusterName
  }
}
module adx 'data/dataExplorer.bicep' = {
  name: 'adxDeployment'
  params: {
    adxClusterName: adxClusterName
    location: location
    eventHubResourceId: eventHub.outputs.eventHubResourceId
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
  }
}

module acr 'kubernetes/acr.bicep' = {
  name: 'acrDeployment'
  params: {
    acrName: acrName
    location: location
  }
}

module keyVault 'data/keyVault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    tenantId: spnTenantId
    akvNameSite1: akvNameSite1
    akvNameSite2: akvNameSite2
    location: location
  }
}

module eventGrid 'data/eventGrid.bicep' = {
  name: 'eventGridDeployment'
  params: {
    eventGridNamespaceName: eventGridNamespaceName
    eventHubResourceId: eventHub.outputs.eventHubResourceId
    queueName: storageQueueName
    storageAccountResourceId: storageAccount.outputs.storageAccountResourceId
    namingGuid: namingGuid
    location: location
  }
}

module storageAccount 'storage/storageAccount.bicep' = {
  name: 'aioStorageAccountDeployment'
  params: {
    storageAccountName: aioStorageAccountName
    location: location
    storageQueueName: storageQueueName
    stcontainerName: stcontainerName
  }
}

module eventHub 'data/eventHub.bicep' = {
  name: 'eventHubDeployment'
  params: {
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
    location: location
    stagingDataCGName: stagingDataCGName
  }
}
