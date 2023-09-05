@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

@description('Subscription Id')
param subscriptionId string = subscription().subscriptionId

var policies = [
  /*{
    name: '(ArcBox) Enable Azure Monitor for Hybrid VMs with AMA'
    definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/59e9c3eb-d8df-473b-8059-23fd38ddd0f0'
    roleDefinition: [
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

module policy_dcr_ama 'policyAzureArcDCR.bicep' = {
  name: 'policy_dcr_ama'
  scope: subscription(subscriptionId)
}

/*resource policy_dcr_ama_assignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '(ArcBox) Enable VM Insights'
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    displayName: '(ArcBox) Enable VM Insights'
    policyDefinitionId: policy_dcr_ama.outputs.ama_dcr_policySet_Id
  }
}
*/
