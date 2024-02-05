@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

var policies = [
  {
    name: '(Ag) Enable Azure Monitor for Hybrid VMs with AMA'
    definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/59e9c3eb-d8df-473b-8059-23fd38ddd0f0'
    roleDefinition:  [
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/cd570a14-e51a-42ad-bac8-bafd67325302'
      '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa'
    ]
    scope: resourceGroup().id
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
    name: '(Ag) Deploy Azure Security agent on Windows Arc machines'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/d01f3018-de9f-4d75-8dae-d12c1875da9f'
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
  {
    name: '(Ag) Deploy Azure Security agent on Linux Arc machines'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/2f47ec78-4301-4655-b78e-b29377030cdc'
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    parameters: {}
  }
  {
    name: '(Ag) Deploy MDE agent on Windows Arc machines'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/37c043a6-6d64-656d-6465-b362dfeb354a'
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {}
  }
  {
    name: '(Ag) Deploy MDE agent on Linux Arc machines'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/4eb909e7-6d64-656d-6465-2eeb297a1625'
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    parameters: {}
  }
]

resource policies_name 'Microsoft.Authorization/policyAssignments@2022-06-01' = [for item in policies: {
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

resource policy_AMA_role_0 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
  name: guid( policies[0].name, policies[0].roleDefinition[0],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[0]
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid( policies[0].name, policies[0].roleDefinition[1],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[1]
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid( policies[0].name, policies[0].roleDefinition[2],resourceGroup().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition[2]
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_arc_windows_azure_security_agent 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid( policies[1].name, policies[1].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: policies[1].roleDefinition
    principalId: policies_name[1].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_arc_linux_azure_security_agent 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid( policies[2].name, policies[2].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: policies[2].roleDefinition
    principalId: policies_name[2].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_arc_windows_mde 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid( policies[3].name, policies[3].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: policies[3].roleDefinition
    principalId: policies_name[3].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_arc_linux_mde 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid( policies[4].name, policies[4].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: policies[4].roleDefinition
    principalId: policies_name[4].identity.principalId
    principalType: 'ServicePrincipal'
  }
}
