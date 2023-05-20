@description('Location of your Azure resources')
param azureLocation string

targetScope = 'subscription'

var policies = [
    {
    name: '(Ag) Configure Azure Defender for servers to be enabled'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/8e86a5b6-b9bd-49d1-8e21-4bb8a0862222'
    roleDefinition: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/fb1c8493-542b-48eb-b624-b4c8fea62acd'
    scope: subscription()
    parameters: {}
  }
]

resource policies_name 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for item in policies: {
  name: item.name
  location: azureLocation
  scope: subscription()
  identity: {
    type: 'SystemAssigned'
  }
  
  properties: {
    policyDefinitionId: item.definitionId
    parameters: item.parameters
  }
}]

resource policy_defender_servers 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid( policies[0].name, policies[0].roleDefinition,subscription().id)
  properties: {
    roleDefinitionId: policies[0].roleDefinition
    principalId: policies_name[0].identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policy_defender_servers_remediation 'Microsoft.PolicyInsights/remediations@2021-10-01' = {
  name: guid( policies[0].name, policies[0].roleDefinition,subscription().id)
  scope: subscription()
  properties: {
    policyAssignmentId: policies_name[0].id
    policyDefinitionReferenceId: policies[0].definitionId
    resourceDiscoveryMode: 'ReEvaluateCompliance'
  }
}
