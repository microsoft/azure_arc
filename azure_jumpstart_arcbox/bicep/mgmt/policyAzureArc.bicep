@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\'')
param flavor string

var policies = [
  {
    name: '(ArcBox) Enable Azure Monitor for Hybrid VMs with AMA'
    definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/59e9c3eb-d8df-473b-8059-23fd38ddd0f0'
    flavors: [
      'Full'
      'ITPro'
    ]
    roleDefinition:  [
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/cd570a14-e51a-42ad-bac8-bafd67325302'
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa'
    ]
    parameters: {
      logAnalyticsWorkspace: {
        value: logAnalyticsWorkspaceId
      }
      enableProcessesAndDependencies: {
        value: true
      }
    }
  }
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

resource policy_AMA_role_0 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[0].flavors, flavor)) {
  name: guid( policies[0].name, policies[0].roleDefinition[0],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[0]
    principalId: contains(policies[0].flavors, flavor)?policies_name[0].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_1 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[0].flavors, flavor)) {
  name: guid( policies[0].name, policies[0].roleDefinition[1],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[1]
    principalId: contains(policies[0].flavors, flavor)?policies_name[0].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_2 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[0].flavors, flavor)) {
  name: guid( policies[0].name, policies[0].roleDefinition[2],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[2]
    principalId: contains(policies[0].flavors, flavor)?policies_name[0].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_tagging_resources 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[1].flavors, flavor)) {
  name: guid( policies[1].name, policies[1].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: policies[1].roleDefinition
    principalId: contains(policies[1].flavors, flavor)?policies_name[1].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_defender_kubernetes 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[2].flavors, flavor)) {
  name: guid( policies[2].name, policies[2].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: policies[2].roleDefinition
    principalId: contains(policies[2].flavors, flavor)?policies_name[2].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

