targetScope = 'subscription'

param dependencyAgentLinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/deacecc0-9f84-44d2-bb82-46f32d766d43'
param dependencyAgentWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/91cb9edd-cd92-4d2f-b2f2-bdd8d065a3d4'
param AMAWindowsPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/94f686d6-9a24-4e19-91f1-de937dc171a4'
param AMALinuxPolicyId string = '/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122'


resource monitoring_policies 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '(ArcBox) Deploy Azure Monitor agents'
  properties: {
    displayName: '(ArcBox) Deploy Azure Monitor agents'
    policyDefinitions: [
      {
        policyDefinitionId: dependencyAgentLinuxPolicyId
      }
      {
        policyDefinitionId: dependencyAgentWindowsPolicyId
      }
      {
        policyDefinitionId: AMAWindowsPolicyId
      }
      {
        policyDefinitionId: AMALinuxPolicyId
      }
    ]
  }
}
