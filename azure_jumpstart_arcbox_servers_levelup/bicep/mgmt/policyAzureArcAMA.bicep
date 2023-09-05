targetScope = 'subscription'

param AzureMonitorAgentLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122'
param AMALinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74'
param dependencyAgentLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43'

param AzureMonitorAgentWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/94f686d6-9a24-4e19-91f1-de937dc171a4'
param AMAWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c'
param dependencyAgentWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/91cb9edd-cd92-4d2f-b2f2-bdd8d065a3d4'


resource monitoring_policies_Linux 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '(ArcBox) Deploy Azure Monitor agents on Arc-enabled Linux VMs'
  properties: {
    displayName: '(ArcBox) Deploy Azure Monitor agents on Linux machines'
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
        policyDefinitionId: dependencyAgentLinuxPolicyId
      }
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
  name: '(ArcBox) Deploy Azure Monitor agents on Arc-enabled Windows VMs'
  properties: {
    displayName: '(ArcBox) Deploy Azure Monitor agents on Windows machines'
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
