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

@description('Azure service principal object id')
param spnObjectId string

@description('Secret name')
param aioPlaceHolder string = 'azure-iot-operations'

@description('Secret value')
param aioPlaceHolderValue string = 'aioSecretValue'

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_azure_aio'
}

resource userAssignedManagedIdentitySeattle 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'aio-seattle-identity'
  location: location
}

resource userAssignedManagedIdentityChicago 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'aio-chicago-identity'
  location: location
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
    enableRbacAuthorization: true
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
    enableRbacAuthorization: true
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

// Add role assignment for the SPN: Key Vault Secrets Officer
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(spnObjectId, resourceGroup().id, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  scope: resourceGroup()
  properties: {
    principalId: spnObjectId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalType: 'ServicePrincipal'
    description: 'Key Vault Secrets Officer'

  }
}

// Add role assignment for the SPN: Key Vault Secrets Officer
resource roleAssignmentAIOSeattle 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(userAssignedManagedIdentitySeattle.name, resourceGroup().id, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedManagedIdentitySeattle.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalType: 'ServicePrincipal'
    description: 'Key Vault Secrets Officer'

  }
}

// Add role assignment for the SPN: Key Vault Secrets Officer
resource roleAssignmentAIOChicago 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(userAssignedManagedIdentityChicago.name, resourceGroup().id, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedManagedIdentityChicago.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalType: 'ServicePrincipal'
    description: 'Key Vault Secrets Officer'

  }
}