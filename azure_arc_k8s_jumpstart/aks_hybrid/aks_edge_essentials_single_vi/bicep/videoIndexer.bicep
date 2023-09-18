@description('The location to deploy this resource to')
param location string = resourceGroup().location

@description('The name of the AVAM resource')
param accountName string = 'jsviaccount${uniqueString(resourceGroup().id)}'

//@description('The managed identity Resource Id used to grant access to the Azure Media Service (AMS) account')
//param managedIdentityResourceId string

@description('The media Service Account Id. The Account needs to be created prior to the creation of this template')
param mediaServiceAccountResourceId string 

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
      //userAssignedIdentity: managedIdentityResourceId
    }
  }
}

output videoIndexerAccountName string = avamAccount.name
output videoIndexerAccountId string = avamAccount.properties.accountId
