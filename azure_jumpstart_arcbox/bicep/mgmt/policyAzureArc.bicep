@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\'')
param flavor string

@description('The id of the Linux data collection rules')
param linuxDcrId string

@description('The id of the Windows data collection rules')
param windowsDcrId string

@description('The id of the maintenance config')
param maintenanceConfigId string

var policies = [
  {
    name: '(ArcBox) Deploy Linux Azure Monitor agents'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
  {
    name: '(ArcBox) Deploy Windows Azure Monitor agents'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/94f686d6-9a24-4e19-91f1-de937dc171a4'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
  {
    name: '(ArcBox) Configure Linux machines data collection rules'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/d5c37ce1-5f52-4523-b949-f19bf945b73a'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {
      dcrResourceId: {
        value: linuxDcrId
      }
    }
  }
  {
    name: '(ArcBox) Configure Windows machines data collection rules'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/c24c537f-2516-4c2f-aac5-2cd26baa3d26'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {
      dcrResourceId: {
        value: windowsDcrId
      }
    }
  }
  {
    name: '(ArcBox) Configure VMInsights DCRs'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/7c4214e9-ea57-487a-b38e-310ec09bc21d'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {
      workspaceResourceId: logAnalyticsWorkspaceId
      enableProcessesAndDependencies: true
    }
  }
  {
    name: '(ArcBox) Configure periodic update assessments'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/ba0df93e-e4ac-479a-aac2-134bbae39a1a'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {
      maintenanceConfigurationResourceId: maintenanceConfigId
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

resource policies_name 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for item in policies: if (contains(item.flavors, flavor)) {
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

resource policies_name_id 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' =  [for (item,i) in policies: if (contains(item.flavors, flavor)) {
  name: guid( item.name, resourceGroup().id)
  properties: {
    roleDefinitionId: item.roleDefinition
    principalId: contains(item.flavors, flavor)?policies_name[i].identity.principalId:guid('policies_name_id${i}')
    principalType: 'ServicePrincipal'
  }
}]
