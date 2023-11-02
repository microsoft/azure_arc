@description('Azure Key Vault name')
param akvName string = 'ft1-akv-01'

@description('Azure Key Vault location')
param location string = resourceGroup().location

@description('Azure Key Vault SKU')
param akvSku string = 'standard'

@description('Azure Key Vault tenant ID')
param tenantId string = subscription().tenantId

@description('Secret name')
param ft1PlaceHolder string = 'azure-iot-operations'

@description('Secret value')
param ft1PlaceHolderValue string = 'ft1SecretValue'

@description('Unique SPN app ID')
param spnClientId string

@description('Unique SPN object ID')
param spnObjectId string

resource akv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: akvName
  location: location
  properties: {
    sku: {
      name: akvSku
      family: 'A'
    }
    accessPolicies: [
      {
        objectId: spnObjectId
        permissions: {
          secrets:[
            'get'
            'list'
            'set'
          ]
        }
        tenantId: tenantId
        applicationId: spnClientId
      }
    ]
    enableSoftDelete: false
    tenantId: tenantId
  }
}

resource ft1SecretPlaceholder 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: ft1PlaceHolder
  parent: akv
  properties: {
    value: ft1PlaceHolderValue
  }
}
