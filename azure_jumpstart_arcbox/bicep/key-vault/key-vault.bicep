@description('Azure service principal client id')
param spnClientId string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\'')
@allowed([
  'Full'
  'ITPro'
  'DevOps'
])
param flavor string = 'Full'

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = if (flavor == 'DevOps') {
  name: 'kv-arcbox-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: spnTenantId
    accessPolicies: [
      {
        objectId: spnClientId
        permissions: {
          certificates: [
            'all'
          ]
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
          storage: [
            'all'
          ]
        }
        tenantId: spnTenantId
      }
    ]
  }
}
