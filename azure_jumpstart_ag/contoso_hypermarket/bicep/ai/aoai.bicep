@description('The name of the OpenAI Cognitive Services account')
param openAIAccountName string = 'openai${uniqueString(resourceGroup().id,location)}'

@description('The location of the OpenAI Cognitive Services account')
param location string

@description('The name of the OpenAI Cognitive Services SKU')
param openAISkuName string = 'S0'

@description('The type of Cognitive Services account to create')
param cognitiveSvcType string = 'AIServices'

param openAIModels array = [
  {
    name: 'gpt-4o-mini'
    version: '2024-07-18'
  }
  {
    name: 'gpt-35-turbo'
    version: '0125'
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

resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = [for model in openAIModels: {
  parent: openAIAccount
  name: '${openAIAccountName}${model.name}'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.name
      version: model.version
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    currentCapacity: 10
    raiPolicyName: 'Microsoft.Default'
  }
}]