@description('Location of your Azure resources')
param azureLocation string

//@description('Name of your log analytics workspace')
//param logAnalyticsWorkspaceId string

@description('Subscription Id')
param subscriptionId string = subscription().subscriptionId

@description('Id of change tracking DCR')
param changeTrackingDCR string

param changeTrackingPolicySetDefintion string = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/policySetDefinitions/(ArcBox) Enable ChangeTracking for Arc-enabled machines'
param contributorRoleDefinition string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

param connectedMachineResourceAdminRole string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/cd570a14-e51a-42ad-bac8-bafd67325302'
param monitoringContributorRole string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa'
param logAnalyticsContributor string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'

param taggingPolicyDefintionId string = '/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26'

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
    definitionId: taggingPolicyDefintionId
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


resource taggingPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '(ArcBox) Tag resources'
  location: azureLocation
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    displayName: '(ArcBox) Tag resources'
    description: 'Tag resources'
    policyDefinitionId: taggingPolicyDefintionId
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

/*resource policies_name 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for item in policies: {
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
*/

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

resource changeTrackingPolicyRoleAssignments1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(changeTrackingPolicyAssignemnt.name,connectedMachineResourceAdminRole, resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: connectedMachineResourceAdminRole
    principalId: changeTrackingPolicyAssignemnt.identity.principalId
  }
}

resource changeTrackingPolicyRoleAssignments2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(changeTrackingPolicyAssignemnt.name,logAnalyticsContributor, resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: logAnalyticsContributor
    principalId: changeTrackingPolicyAssignemnt.identity.principalId
  }
}

resource changeTrackingPolicyRoleAssignments3 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(changeTrackingPolicyAssignemnt.name,monitoringContributorRole, resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: monitoringContributorRole
    principalId: changeTrackingPolicyAssignemnt.identity.principalId
  }
}


resource policy_tagging_resources 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(taggingPolicyAssignment.name, policies[0].roleDefinition, resourceGroup().id)
  properties: {
    roleDefinitionId: contributorRoleDefinition
    principalId: taggingPolicyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module arcAMAPolicies 'policySetDefinitionsAzureArc.bicep' = {
  name: guid('ARCBOX_AMA_POLICIES',subscriptionId,azureLocation)
  scope: subscription(subscriptionId)
}
