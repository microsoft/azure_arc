@description('The location to deploy this resource to')
param location string = resourceGroup().location

@description('The name of the AVAM resource')
param accountName string = 'jsviaccount${uniqueString(resourceGroup().id)}'

//@description('The managed identity Resource Id used to grant access to the Azure Media Service (AMS) account')
//param managedIdentityResourceId string

@description('The media service account name')
param mediaServiceAccountName string

@description('The media Service Account Id. The Account needs to be created prior to the creation of this template')
param mediaServiceAccountResourceId string 

var contributorRoleDefinitionResourceId = '/subscriptions/16471a83-9151-456e-bbb1-463027bed604/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('The AVAM Template')
resource avamAccount 'Microsoft.VideoIndexer/accounts@2022-08-01' = {
  name: accountName
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  properties: {
    mediaServices: {
      resourceId: mediaServiceAccountResourceId
    }
  }
}

resource mediaService 'Microsoft.Media/mediaservices@2021-06-01' existing = {
  name: mediaServiceAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mediaService.id, avamAccount.id, contributorRoleDefinitionResourceId)
  scope: mediaService
  properties: {
    roleDefinitionId: contributorRoleDefinitionResourceId
    principalId: avamAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output videoIndexerAccountName string = avamAccount.name
output videoIndexerAccountId string = avamAccount.properties.accountId
output videoIndexerPrincipalId string = avamAccount.identity.principalId
