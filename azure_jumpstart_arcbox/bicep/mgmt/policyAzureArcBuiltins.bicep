@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspace string

var logAnalyticsResource = resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspace)
var policyDefinitionForLinuxDeployLogAnalytics = '/providers/Microsoft.Authorization/policyDefinitions/9d2b61b4-1d14-4a63-be30-d4498e7ad2cf'
var policyDefinitionForWindowsDeployLogAnalytics = '/providers/Microsoft.Authorization/policyDefinitions/69af7d4a-7b18-4044-93a9-2651498ef203'
var policyDefinitionForAddResourceTag = '/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26'
var policyDefinitionForLinuxDeployDependencyAgent = '/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43'
var policyDefinitionForWindowsDeployDependencyAgent = '/providers/Microsoft.Authorization/policyDefinitions/91cb9edd-cd92-4d2f-b2f2-bdd8d065a3d4'
var policyDefinitionForEnableAzureDefenderKubernetes = '/providers/Microsoft.Authorization/policyDefinitions/708b60a6-d253-4fe0-9114-4be4c00f012c'
var policyNameForLinuxDeployLogAnalytics_var = '(ArcBox) Deploy Linux Log Analytics agents'
var policyNameForWindowsDeployLogAnalytics_var = '(ArcBox) Deploy Windows Log Analytics agents'
var policyNameForLinuxDeployDependencyAgent_var = '(ArcBox) Deploy Linux Dependency Agents'
var policyNameForWindowsDeployDependencyAgent_var = '(ArcBox) Deploy Windows Dependency Agents'
var policyNameForAddResourceTag_var = '(ArcBox) Tag resources'
var policyNameForEnableAzureDefenderKubernetes_var = '(ArcBox) Enable Azure Defender on Kubernetes clusters'
var logAnalyticsContributorRoleDefinition = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
var tagContributorRoleDefinition = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

resource policyNameForLinuxDeployLogAnalytics 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForLinuxDeployLogAnalytics_var
  location: azureLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyDefinitionForLinuxDeployLogAnalytics
    parameters: {
      logAnalytics: {
        value: logAnalyticsResource
      }
    }
  }
}

resource policyNameForLinuxDeployLogAnalytics_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForLinuxDeployLogAnalytics_var, resourceGroup().id)
  properties: {
    roleDefinitionId: logAnalyticsContributorRoleDefinition
    principalId: reference(policyNameForLinuxDeployLogAnalytics.id, '2019-09-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policyNameForWindowsDeployLogAnalytics 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForWindowsDeployLogAnalytics_var
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyDefinitionForWindowsDeployLogAnalytics
    parameters: {
      logAnalytics: {
        value: logAnalyticsResource
      }
    }
  }
}

resource policyNameForWindowsDeployLogAnalytics_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForWindowsDeployLogAnalytics_var, resourceGroup().id)
  properties: {
    roleDefinitionId: logAnalyticsContributorRoleDefinition
    principalId: reference(policyNameForWindowsDeployLogAnalytics.id, '2019-09-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policyNameForLinuxDeployDependencyAgent 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForLinuxDeployDependencyAgent_var
  location: azureLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyDefinitionForLinuxDeployDependencyAgent
    parameters: {}
  }
}

resource policyNameForLinuxDeployDependencyAgent_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForLinuxDeployDependencyAgent_var, resourceGroup().id)
  properties: {
    roleDefinitionId: logAnalyticsContributorRoleDefinition
    principalId: reference(policyNameForLinuxDeployDependencyAgent.id, '2019-09-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policyNameForWindowsDeployDependencyAgent 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForWindowsDeployDependencyAgent_var
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyDefinitionForWindowsDeployDependencyAgent
    parameters: {}
  }
}

resource policyNameForWindowsDeployDependencyAgent_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForWindowsDeployDependencyAgent_var, resourceGroup().id)
  properties: {
    roleDefinitionId: logAnalyticsContributorRoleDefinition
    principalId: reference(policyNameForWindowsDeployDependencyAgent.id, '2019-09-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policyNameForAddResourceTag 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForAddResourceTag_var
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
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

resource policyNameForAddResourceTag_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForAddResourceTag_var, resourceGroup().id)
  properties: {
    roleDefinitionId: tagContributorRoleDefinition
    principalId: reference(policyNameForAddResourceTag.id, '2019-09-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource policyNameForEnableAzureDefenderKubernetes 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyNameForEnableAzureDefenderKubernetes_var
  identity: {
    type: 'SystemAssigned'
  }
  location: azureLocation
  properties: {
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyDefinitionForEnableAzureDefenderKubernetes
    parameters: {}
  }
}

resource policyNameForEnableAzureDefenderKubernetes_id 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(policyNameForEnableAzureDefenderKubernetes_var, resourceGroup().id)
  properties: {
    roleDefinitionId: logAnalyticsContributorRoleDefinition
    principalId: reference(policyNameForEnableAzureDefenderKubernetes.id, '2019-09-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}
