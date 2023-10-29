@description('Azure Key Vault name')
param akvName string = 'ft1-akv-01'

@description('Azure Key Vault location')
param location string = resourceGroup().location

@description('Azure Key Vault SKU')
param akvSku string = 'standard'

@description('Azure Key Vault tenant ID')
param tenantId string = subscription().tenantId

@description('SPN app ID')
param spnClientId string

@description('SPN object ID')
param spnObjectId string

@description('Secret name')
param ft1Secret string = 'PlaceholderSecret'

@description('Secret value')
param ft1SecretValue string = 'ft1SecretValue'

resource akv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: akvName
  location: location
  properties: {
    sku: {
      name: akvSku
      family: 'A'
    }
    enableSoftDelete: false
    tenantId: tenantId
    accessPolicies: [
      {
        applicationId: spnClientId
        objectId: spnObjectId
        tenantId: tenantId
        permissions: {
          secrets: [
            'all'
          ]
          keys: [
            'all'
          ]
          certificates: [
            'all'
          ]
        }
      }
    ]
  }
}

resource ft1SecretPlaceholder 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: ft1Secret
  parent: akv
  properties: {
    value: ft1SecretValue
  }
}
