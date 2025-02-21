@description('Location of your Azure resources')
param azureLocation string

@description('Name of your log analytics workspace')
param logAnalyticsWorkspaceId string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'DataOps\', \'DevOps\', \'ITPro\'')
param flavor string

@description('Tags to assign for all ArcBox resources')
param resourceTags object = {
  Solution: 'jumpstart_arcbox'
}

param azureUpdateManagerArcPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/bfea026e-043f-4ff4-9d1b-bf301ca7ff46'
param azureUpdateManagerAzurePolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15'
param sshPostureControlAzurePolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/a8f3e6a6-dcd2-434c-b0f7-6f309ce913b4'

param tagsRoleDefinitionId string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

var policies = [
  {
    name: '(ArcBox) Enable Azure Monitor for Hybrid VMs with AMA'
    definitionId: '/providers/Microsoft.Authorization/policySetDefinitions/59e9c3eb-d8df-473b-8059-23fd38ddd0f0'
    flavors: [
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
        value: false
      }
    }
  }
  {
    name: '(ArcBox) Enable Microsoft Defender on Kubernetes clusters'
    definitionId: '/providers/Microsoft.Authorization/policyDefinitions/708b60a6-d253-4fe0-9114-4be4c00f012c'
    flavors: [
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
    policyDefinitionId: any(item.definitionId)
    parameters: item.parameters
  }
}]

resource policy_AMA_role_0 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[0].flavors, flavor)) {
  name: guid( policies[0].name, policies[0].roleDefinition[0],resourceGroup().id)
  properties: {
    roleDefinitionId: any(policies[0].roleDefinition[0])
    principalId: contains(policies[0].flavors, flavor)?policies_name[0].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_1 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[0].flavors, flavor)) {
  name: guid( policies[0].name, policies[0].roleDefinition[1],resourceGroup().id)
  properties: {
    roleDefinitionId: any(policies[0].roleDefinition[1])
    principalId: contains(policies[0].flavors, flavor)?policies_name[0].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_AMA_role_2 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[0].flavors, flavor)) {
  name: guid( policies[0].name, policies[0].roleDefinition[2],resourceGroup().id)
  properties: {
    roleDefinitionId: any(policies[0].roleDefinition[2])
    principalId: contains(policies[0].flavors, flavor)?policies_name[0].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}

resource policy_defender_kubernetes 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (contains(policies[1].flavors, flavor)) {
  name: guid( policies[1].name, policies[1].roleDefinition,resourceGroup().id)
  properties: {
    roleDefinitionId: any(policies[1].roleDefinition)
    principalId: contains(policies[1].flavors, flavor)?policies_name[1].identity.principalId:guid('policies_name_id${0}')
    principalType: 'ServicePrincipal'
  }
}


resource applyCustomTags 'Microsoft.Authorization/policyAssignments@2021-06-01' = [for (tag,i) in items(resourceTags): {
  name: '(ArcBox) Tag resources-${tag.key}'
  location: azureLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: any('/providers/Microsoft.Authorization/policyDefinitions/4f9dc7db-30c1-420c-b61a-e1d640128d26')
    parameters:{
      tagName: {
        value: tag.key
      }
      tagValue: {
        value: tag.value
      }
    }
  }
}]

resource policy_tagging_resources 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for (tag,i) in items(resourceTags): {
  name: guid(applyCustomTags[i].name, tagsRoleDefinitionId,resourceGroup().id)
  properties: {
    roleDefinitionId: tagsRoleDefinitionId
    principalId: applyCustomTags[i].identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource updateManagerArcPolicyLinux 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '(ArcBox) Enable Azure Update Manager for Linux hybrid machines'
  location: azureLocation
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    displayName: '(ArcBox) Enable Azure Update Manager for Arc-enabled Linux machines'
    description: 'Enable Azure Update Manager for Arc-enabled machines'
    policyDefinitionId: azureUpdateManagerArcPolicyId
    parameters: {
      osType: {
        value: 'Linux'
      }
    }
  }
}

resource updateManagerArcPolicyWindows 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '(ArcBox) Enable Azure Update Manager for Windows hybrid machines'
  location: azureLocation
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    displayName: '(ArcBox) Enable Azure Update Manager for Arc-enabled Windows machines'
    description: 'Enable Azure Update Manager for Arc-enabled machines'
    policyDefinitionId: azureUpdateManagerArcPolicyId
    parameters: {
      osType: {
        value: 'Windows'
      }
    }
  }
}

resource updateManagerAzurePolicyWindows  'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '(ArcBox) Enable Azure Update Manager for Azure Windows machines'
  location: azureLocation
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    displayName: '(ArcBox) Enable Azure Update Manager for Azure Windows machines'
    description: 'Enable Azure Update Manager for Azure machines'
    policyDefinitionId: azureUpdateManagerAzurePolicyId
    parameters: {
      osType: {
        value: 'Windows'
      }
    }
  }
}

resource updateManagerAzurePolicyLinux  'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '(ArcBox) Enable Azure Update Manager for Azure Linux machines'
  location: azureLocation
  scope: resourceGroup()
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    displayName: '(ArcBox) Enable Azure Update Manager for Azure Linux machines'
    description: 'Enable Azure Update Manager for Azure machines'
    policyDefinitionId: azureUpdateManagerAzurePolicyId
    parameters: {
      osType: {
        value: 'Linux'
      }
    }
  }
}

resource sshPostureControlAudit  'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '(ArcBox) Enable SSH Posture Control audit'
  location: azureLocation
  scope: resourceGroup()
  properties:{
    displayName: '(ArcBox) Enable SSH Posture Control audit'
    description: 'Enable SSH Posture Control in audit mode'
    policyDefinitionId: sshPostureControlAzurePolicyId
    parameters: {
      IncludeArcMachines: {
        value: 'true'
      }
    }
  }
}
