@description('Storage account name')
param storageAccountName string

@description('Storage account location')
param location string = resourceGroup().location

@description('Storage account kind')
param kind string = 'StorageV2'

@description('Storage account sku')
param skuName string = 'Standard_LRS'

param storageQueueName string = 'aioQueue'

@description('Azure service principal object id')
param spnObjectId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: kind
  sku: {
    name: skuName
  }
  properties: {
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
  }
}

resource storageQueueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource storageQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-01-01' = {
  parent: storageQueueServices
  name: storageQueueName
}

// Add role assignment for the SPN: Storage Blob Data Contributor
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(spnObjectId, resourceGroup().id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: resourceGroup()
  properties: {
    principalId: spnObjectId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalType: 'ServicePrincipal'
    description: 'Storage Blob Data Contributor'

  }
}

output queueName string = storageQueueName
output storageAccountResourceId string = storageAccount.id
