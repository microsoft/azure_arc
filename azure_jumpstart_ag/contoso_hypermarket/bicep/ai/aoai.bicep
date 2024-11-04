@description('The name of the OpenAI Cognitive Services account')
param openAIAccountName string = 'openai${uniqueString(resourceGroup().id,location)}'

@description('The location of the OpenAI Cognitive Services account')
param location string = resourceGroup().location

@description('The name of the OpenAI Cognitive Services SKU')
param openAISkuName string = 'S0'

@description('The type of Cognitive Services account to create')
param cognitiveSvcType string = 'AIServices'

@description('Azure service principal object id')
param spnObjectId string

@description('The array of OpenAI models to deploy')
param azureOpenAIModels array = [
  {
    name: 'gpt-35-turbo'
    version: '0301'
  }
  {
    name: 'gpt-4o-mini'
    version: '2024-07-18'
  }
]

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' = {
  name: openAIAccountName
  location: location
  sku: {
    name: openAISkuName
  }
  kind: cognitiveSvcType
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

@batchSize(1)
resource openAIModelsDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = [for model in azureOpenAIModels: {
  parent: openAIAccount
  name: '${openAIAccountName}-${model.name}-deployment'
  sku: {
    name: 'GlobalStandard'
    capacity: 50
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.name
      version: model.version
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    currentCapacity: 50
    raiPolicyName: 'Microsoft.Default'
  }
}]

// Add role assignment for the SPN: Cognitive Services OpenAI Contributor
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(spnObjectId, resourceGroup().id, 'a001fd3d-188f-4b5d-821b-7da978bf7442')
  scope: resourceGroup()
  properties: {
    principalId: spnObjectId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
    principalType: 'ServicePrincipal'
    description: 'Cognitive Services OpenAI Contributor'

  }
}

output openAIEndpoint string = filter(items(openAIAccount.properties.endpoints), endpoint => endpoint.key == 'OpenAI Language Model Instance API')[0].value
output speechToTextEndpoint string = filter(items(openAIAccount.properties.endpoints), endpoint => endpoint.key == 'Speech Services Speech to Text')[0].value


