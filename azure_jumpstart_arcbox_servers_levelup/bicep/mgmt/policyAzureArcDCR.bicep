targetScope = 'subscription'

@description('Definition Id of the AMA DCR Linux policy')
param linuxAMAPolicyDefinitionId string = '/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c'

@description('Definition Id of the AMA DCR Windows policy')
param windowsAMAPolicyDefinitionId string = '/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74'


resource ama_dcr_policy_set 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: '(ArcBox) Enable VM Insights'
  properties: {
    displayName: '(ArcBox) Enable VM Insights'
    parameters: {
      'dcrResourceId': {
        'type': string,
        'metadata': {
          'displayName': 'VM insight DCR resource Id',
          'description': 'VM insight DCR resource Id'
        },
    }
    policyDefinitions: [
      {
        policyDefinitionId: linuxAMAPolicyDefinitionId
        parameters: {
          dcrResourceId : {
            value: parameters('dcrResourceId')
          }
        }
      }
      {
        policyDefinitionId: windowsAMAPolicyDefinitionId
        parameters: {
          dcrResourceId : {
            value: parameters('dcrResourceId')
          }
        }
      }
    ]
  }
}

output ama_dcr_policySet_Id string = ama_dcr_policy_set.id
