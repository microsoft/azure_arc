@description('The GUID used for naming')
param namingGuid string

@description('The name of the storage account used by the Synapse workspace.')
param SynapseStorageAccountName string = 'Agsynapsestg${namingGuid}'

@description('The name of the container used by the Synapse workspace.')
param containerName string = 'Agfs'

@description('The name of the Synapse workspace.')
param synapseWorkspaceName string

@description('The location of the Managed Cluster resource')
param location string

@description('The name of the Synapse Data Explorer cluster.')
param dataExplorerClusterName string = 'Agdxcluster'

@description('The name of the Synapse Data Explorer database')
param dataExplorerDatabaseName string = 'Agdxdb'

@description('The Sku of the data explorer cluster')
param dataExplorerSkuName string = 'Compute Optimized'

@description('The Sku size of the data explorer cluster')
param dataExplorerSkuSize string = 'Extra small'

@description('The Sku capacity of the data explorer cluster')
param dataExplorerSkuCapacity int = 2

@description('The user name of the Synapse admin')
param synapseAdminUserName string

@description('The ID of the IoT Hub')
param iotHubId string

@description('The name of the IoT Hub consumer group')
param iotHubConsumerGroup string

@description('The name of the Synapse Data Explorer database')
param dxDatabaseConnection string = 'Agdxdb'


@description('The password of the Synapse admin')
@minLength(12)
@maxLength(123)
@secure()

param synapseAdminPassword string

@description('The role ID of Storage Blob Data Contributor.')
var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource synapseStg 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: SynapseStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    isHnsEnabled: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource AgContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${synapseStg.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
}


resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedVirtualNetwork: 'default'
    sqlAdministratorLogin: synapseAdminUserName
    sqlAdministratorLoginPassword: synapseAdminPassword
    publicNetworkAccess: 'Enabled'
    defaultDataLakeStorage: {
      accountUrl: synapseStg.properties.primaryEndpoints.dfs
      filesystem: 'synapse'
    }
  }
}

resource synapsedx 'Microsoft.Synapse/workspaces/kustoPools@2021-06-01-preview' = {
  name: dataExplorerClusterName
  parent: synapse
  location: location
  sku: {
    name: dataExplorerSkuName
    capacity: dataExplorerSkuCapacity
    size: dataExplorerSkuSize
  }
  properties: {
    workspaceUID: synapse.properties.workspaceUID
  }
}

resource dxdatabase 'Microsoft.Synapse/workspaces/kustoPools/databases@2021-06-01-preview' = {
  name: dataExplorerDatabaseName
  parent: synapsedx
  location: location
  kind: 'ReadWrite'
}

resource dxdatabaseConnection 'Microsoft.Synapse/workspaces/kustoPools/databases/dataConnections@2021-06-01-preview' = {
  name: '${synapse.name}/${synapsedx.name}/${dxdatabase.name}/${dxDatabaseConnection}'
  kind: 'IotHub'
  location: location
  properties: {
    consumerGroup: iotHubConsumerGroup
    iotHubResourceId: iotHubId
    sharedAccessPolicyName: 'iothubowner'
  }
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: synapseStg
  name: guid(synapse.id, storageBlobDataContributorRoleID)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleID)
    principalId: synapse.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
