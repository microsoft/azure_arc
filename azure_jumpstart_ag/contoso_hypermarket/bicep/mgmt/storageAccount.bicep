@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

//@description('Azure service principal object id')
//param spnObjectId string

var storageAccountName = 'agora${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  tags: resourceTags
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
  }
}

// Add role assignment for the SPN: Storage Blob Data Contributo
/*resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(spnObjectId, resourceGroup().id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: resourceGroup()
  properties: {
    principalId: spnObjectId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalType: 'ServicePrincipal'

  }
}*/


output storageAccountName string = storageAccountName
output storageAccountResourceId string = storageAccount.id
