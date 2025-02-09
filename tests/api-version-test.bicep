resource oldStorageAccount 'Microsoft.Storage/storageAccounts@2019-04-01' = {
  name: 'testoldversion'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
