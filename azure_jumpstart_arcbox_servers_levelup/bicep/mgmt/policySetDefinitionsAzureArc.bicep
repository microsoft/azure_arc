targetScope = 'subscription'

param AzureMonitorAgentLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122'
param AMALinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74'
//param dependencyAgentLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43'
//param changeTrackingLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/09a1f130-7697-42bc-8d84-8a9ea17e5187'
param changeTrackingLinuxExtensionPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/10caed8a-652c-4d1d-84e4-2805b7c07278'
param changeTrackingDcrLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/09a1f130-7697-42bc-8d84-8a9ea17e5192'


param AzureMonitorAgentWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/94f686d6-9a24-4e19-91f1-de937dc171a4'
param AMAWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c'
param dependencyAgentWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/91cb9edd-cd92-4d2f-b2f2-bdd8d065a3d4'
//param changeTrackingWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/a7acfae7-9497-4a3f-a3b5-a16a50abbe2f'
param changeTrackingWindowsExtensionPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/4bb303db-d051-4099-95d2-e3e1428a4cd5'
param changeTrackingDcrWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/ef9fe2ce-a588-4edd-829c-6247069dcfdb'


resource monitoring_policies_Linux 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '(ArcBox) Deploy Azure Monitor on Arc-enabled Linux machines'
  properties: {
    displayName: '(ArcBox) Deploy Azure Monitor on Arc-enabled Linux machines'
    description: 'This policy deploys Azure Monitor agents on Linux Arc connected machines.'
    metadata: {
      category: 'Monitoring'
      version: '1.0.0'
    }
    parameters: {
      dcrResourceId: {
        type: 'String'
        metadata: {
          displayName: 'Data Collection Rule Resource Id or Data Collection Endpoint Resource Id'
          description: 'Resource Id of the Data Collection Rule or the Data Collection Endpoint to be applied on the Linux machines in scope.'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: AMALinuxPolicyId
        parameters: {
          dcrResourceId: {
            value: '[parameters(\'dcrResourceId\')]'
          }
        }
      }
      {
        policyDefinitionId: AzureMonitorAgentLinuxPolicyId
      }
    ]
  }
}


resource monitoring_policies_Windows 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '(ArcBox) Deploy Azure Monitor on Arc-enabled Windows machines'
  properties: {
    displayName: '(ArcBox) Deploy Azure Monitor on Arc-enabled Windows machines'
    description: 'This policy deploys Azure Monitor agents on Windows Arc connected machines.'
    metadata: {
      category: 'Monitoring'
      version: '1.0.0'
    }
    parameters: {
      dcrResourceId: {
        type: 'String'
        metadata: {
          displayName: 'Data Collection Rule Resource Id or Data Collection Endpoint Resource Id'
          description: 'Resource Id of the Data Collection Rule or the Data Collection Endpoint to be applied on the Linux machines in scope.'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: dependencyAgentWindowsPolicyId
      }
      {
        policyDefinitionId: AMAWindowsPolicyId
        parameters: {
          dcrResourceId: {
            value: '[parameters(\'dcrResourceId\')]'
          }
        }
      }
      {
        policyDefinitionId: AzureMonitorAgentWindowsPolicyId
      }
    ]
  }
}

resource change_tracking_policies 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '(ArcBox) Enable ChangeTracking for Arc-enabled machines'
  properties: {
    displayName: '(ArcBox) Enable ChangeTracking and Inventory for Arc-enabled machines'
    description: 'Enable ChangeTracking and Inventory for Arc-enabled virtual machines. Takes Data Collection Rule ID as parameter and asks for an option to input applicable locations.'
    metadata: {
      category: 'ChangeTrackingAndInventory'
      version: '1.0.0'
    }
    parameters: {
      dcrResourceId: {
        type: 'String'
        metadata: {
          displayName: 'Data Collection Rule Resource Id or Data Collection Endpoint Resource Id'
          description: 'Resource Id of the Data Collection Rule or the Data Collection Endpoint to be applied on the machines in scope.'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: changeTrackingLinuxExtensionPolicyId
      }
      {
        policyDefinitionId: changeTrackingDcrLinuxPolicyId
        parameters: {
          dcrResourceId: {
            value: '[parameters(\'dcrResourceId\')]'
          }
        }
      }
      {
        policyDefinitionId: changeTrackingWindowsExtensionPolicyId
      }
      {
        policyDefinitionId: changeTrackingDcrWindowsPolicyId
        parameters: {
          dcrResourceId: {
            value: '[parameters(\'dcrResourceId\')]'
          }
        }
      }
    ]
  }
}
