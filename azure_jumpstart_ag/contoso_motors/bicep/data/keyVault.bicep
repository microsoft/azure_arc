@description('Azure Key Vault name')
param akvNameSite1 string = 'aio-akv-01'

@description('Azure Key Vault name')
param akvNameSite2 string = 'aio-akv-02'

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

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_azure_aio'
}

resource akv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: akvNameSite1
  location: location
  tags: resourceTags
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

resource akv2 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: akvNameSite2
  location: location
  tags: resourceTags
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

resource aioSecretPlaceholder2 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: aioPlaceHolder
  parent: akv2
  properties: {
    value: aioPlaceHolderValue
  }
}
