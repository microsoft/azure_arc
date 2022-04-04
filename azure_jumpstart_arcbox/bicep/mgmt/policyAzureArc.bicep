@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\'')
param flavor string

var policies = [
  {
    name: '(ArcBox) Deploy Linux Log Analytics agents'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/9d2b61b4-1d14-4a63-be30-d4498e7ad2cf'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {
      logAnalytics: {
        value: logAnalyticsWorkspaceId
      }
    }
  }
  {
    name: '(ArcBox) Deploy Windows Log Analytics agents'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/69af7d4a-7b18-4044-93a9-2651498ef203'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {
      logAnalytics: {
        value: logAnalyticsWorkspaceId
      }
    }
  }
  {
    name: '(ArcBox) Deploy Linux Dependency Agents'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
  {
    name: '(ArcBox) Deploy Windows Dependency Agents'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/91cb9edd-cd92-4d2f-b2f2-bdd8d065a3d4'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
  {
    name: '(ArcBox) Tag resources'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26'
    flavors: [
      'Full'
      'ITPro'
      'DevOps'
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
  {
    name: '(ArcBox) Enable Microsoft Defender on Kubernetes clusters'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/708b60a6-d253-4fe0-9114-4be4c00f012c'
    flavors: [
      'Full'
      'DevOps'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
]

resource policies_name 'Microsoft.Authorization/policyAssignments@2019-09-01' = [for item in policies: if (contains(item.flavors, flavor)) {
  name: item.name
  location: azureLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    scope: resourceGroup().id
    policyDefinitionId: item.definitionId
    parameters: item.parameters
  }
}]

resource policies_name_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' =  [for (item,i) in policies: if (contains(item.flavors, flavor)) {
  name: guid( item.name, resourceGroup().id)
  properties: {
    roleDefinitionId: item.roleDefinition
    principalId: contains(item.flavors, flavor)?policies_name[i].identity.principalId:guid('policies_name_id${i}')
    principalType: 'ServicePrincipal'
  }
}]
