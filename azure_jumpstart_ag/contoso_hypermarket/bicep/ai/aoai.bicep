@description('The name of the OpenAI Cognitive Services account')
param openAIAccountName string = 'openai${uniqueString(resourceGroup().id,location)}'

@description('The location of the OpenAI Cognitive Services account')
param location string = resourceGroup().location

@description('The name of the OpenAI Cognitive Services SKU')
param openAISkuName string = 'S0'

@description('The capacity of the OpenAI Cognitive Services account')
param openAICapacity int = 10

@description('The type of Cognitive Services account to create')
param cognitiveSvcType string = 'AIServices'

@description('The deployment type of the Cognitive Services account')
@allowed([
  'ProvisionedManaged'
  'Standard'
  'GlobalStandard'
])
param azureOpenAiSkuName string = 'GlobalStandard'

@description('The array of OpenAI models to deploy')
param azureOpenAIModel object = {
    name: 'gpt-4o'
    version: '2024-05-13'
  }

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

resource openAIModelsDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = {
  parent: openAIAccount
  name: '${openAIAccountName}-${azureOpenAIModel.name}-deployment'
  sku: {
    name: azureOpenAiSkuName
    capacity: openAICapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: azureOpenAIModel.name
      version: azureOpenAIModel.version
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    currentCapacity: openAICapacity
    raiPolicyName: 'Microsoft.Default'
  }
}

output openAIEndpoint string = filter(items(openAIAccount.properties.endpoints), endpoint => endpoint.key == 'OpenAI Language Model Instance API')[0].value
output speechToTextEndpoint string = filter(items(openAIAccount.properties.endpoints), endpoint => endpoint.key == 'Speech Services Speech to Text (Standard)')[0].value
output openAIDeploymentName string = openAIModelsDeployment.name