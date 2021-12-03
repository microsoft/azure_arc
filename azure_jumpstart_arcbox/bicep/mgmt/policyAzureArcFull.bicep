@description('Location of your Azure resources')
param azureLocation string

var policyDefinitionForEnableAzureDefenderKubernetes = '/providers/Microsoft.Authorization/policyDefinitions/708b60a6-d253-4fe0-9114-4be4c00f012c'
var policyNameForEnableAzureDefenderKubernetes = '(ArcBox) Enable Azure Defender on Kubernetes clusters'
var logAnalyticsContributorRoleDefinition = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'

resource policyForEnableAzureDefenderKubernetes 'Microsoft.Authorization/policyAssignments@2021-06-01' =   {
  name: policyNameForEnableAzureDefenderKubernetes
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    policyDefinitionId: policyDefinitionForEnableAzureDefenderKubernetes
    parameters: {}
  }
}

resource policyForEnableAzureDefenderKubernetesRoleAssigment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForEnableAzureDefenderKubernetes, resourceGroup().id)
  properties: {
    roleDefinitionId: logAnalyticsContributorRoleDefinition
    principalId: policyForEnableAzureDefenderKubernetes.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
