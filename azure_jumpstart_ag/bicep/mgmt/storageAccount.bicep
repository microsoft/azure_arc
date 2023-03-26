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

var storageAccountName = 'agora${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource kubefilesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = if (false) {
  name: '${storageAccountName}/default/kubefiles'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

output storageAccountName string = storageAccountName
