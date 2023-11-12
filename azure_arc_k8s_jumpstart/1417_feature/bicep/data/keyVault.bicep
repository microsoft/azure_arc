@description('Azure Key Vault name')
param akvName string = 'aio-akv-01'

@description('Azure Key Vault location')
param location string = resourceGroup().location

@description('Azure Key Vault SKU')
param akvSku string = 'standard'

@description('Azure Key Vault tenant ID')
param tenantId string = subscription().tenantId

@description('Secret name')
param aioPlaceHolder string = 'azure-iot-operations'

@description('Secret value')
param aioPlaceHolderValue string = 'aioSecretValue'

resource akv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: akvName
  location: location
  properties: {
    sku: {
      name: akvSku
      family: 'A'
    }
    accessPolicies: []
    enableSoftDelete: false
    tenantId: tenantId
  }
}

resource aioSecretPlaceholder 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: aioPlaceHolder
  parent: akv
  properties: {
    value: aioPlaceHolderValue
  }
}
