@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'Full'
  'ITPro'
  'DevOps'
])
param flavor string

var policyDefinitionForAddResourceTag = '/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26'
var policyNameForAddResourceTagName = '(ArcBox) Tag resources'
var tagContributorRoleDefinition = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

resource policyForAddResourceTag 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForAddResourceTagName
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    policyDefinitionId: policyDefinitionForAddResourceTag
    parameters: {
      tagName: {
        value: 'Project'
      }
      tagValue: {
        value: 'jumpstart_arcbox'
      }
    }
  }
}

resource policyForAddResourceTagRoleAssigment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForAddResourceTagName, resourceGroup().id)
  properties: {
    roleDefinitionId: tagContributorRoleDefinition
    principalId: policyForAddResourceTag.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module policyAzureArcFull './policyAzureArcFull.bicep' = if (flavor == 'Full') {
  name: 'policyAzureArcFull'
  params: {
    azureLocation: azureLocation
  }
}
