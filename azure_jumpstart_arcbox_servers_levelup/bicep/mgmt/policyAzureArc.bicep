@description('Location of your Azure resources')
param azureLocation string

//@description('Name of your log analytics workspace')
//param logAnalyticsWorkspaceId string

@description('Subscription Id')
param subscriptionId string = subscription().subscriptionId

@description('Id of change tracking DCR')
param changeTrackingDCR string

param changeTrackingPolicySetDefintion string = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/policySetDefinitions/(ArcBox) Enable ChangeTracking for Arc-enabled machines'
param contributorRoleDefinition string = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

var policies = [
  /*{
    name: '(ArcBox) Enable Azure Monitor for Hybrid Linux VMs with AMA'
    definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/118f04da-0375-44d1-84e3-0fd9e1849403'
    roleDefinition: [
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122'
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74'
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43'
    ]
    parameters: {
      logAnalyticsWorkspace: {
        value: logAnalyticsWorkspaceId
      }
      enableProcessesAndDependencies: {
        value: true
      }
    }
  }*/
  {
    name: '(ArcBox) Tag resources'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26'
    flavors: [
      'Full'
      'ITPro'
      'DevOps'
      'DataOps'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {
      tagName: {
        value: 'Project'
      }
      tagValue: {
        value: 'jumpstart_arcbox'
      }
    }
  }
]

resource policies_name 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for item in policies: {
  name: item.name
  location: azureLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: item.definitionId
    parameters: item.parameters
  }
}]

resource changeTrackingPolicyAssignemnt 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '(ArcBox) Enable ChangeTracking for Arc-enabled machines'
  location: azureLocation
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    displayName: '(ArcBox) Enable ChangeTracking for Arc-enabled machines'
    description: 'Enable ChangeTracking for Arc-enabled machines'
    policyDefinitionId: changeTrackingPolicySetDefintion
    parameters: {
      dcrResourceId:{
        value: changeTrackingDCR
      }
    }
  }
}

resource changeTrackingRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01'={
  name: guid('(ArcBox) Enable ChangeTracking for Arc-enabled machines',resourceGroup().id)
  properties:{
    roleDefinitionId: contributorRoleDefinition
    principalId: changeTrackingPolicyAssignemnt.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

/*resource policy_AMA_role_0 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid( policies[0].name, policies[0].roleDefinition[0],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[0]
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_1 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid( policies[0].name, policies[0].roleDefinition[1],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[1]
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_2 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid( policies[0].name, policies[0].roleDefinition[2],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[2]
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}
*/


resource policy_tagging_resources 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(policies[0].name, policies[0].roleDefinition, resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module arcAMAPolicies 'policySetDefinitionsAzureArc.bicep' = {
  name: guid('ARCBOX_AMA_POLICIES',subscriptionId,azureLocation)
  scope: subscription(subscriptionId)
}
