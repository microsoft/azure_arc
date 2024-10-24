@description('The name of the OpenAI Cognitive Services account')
param openAIAccountName string = 'openai${uniqueString(resourceGroup().id,location)}'

@description('The location of the OpenAI Cognitive Services account')
param location string

@description('The name of the OpenAI Cognitive Services SKU')
param openAISkuName string = 'S0'

@description('The type of Cognitive Services account to create')
param cognitiveSvcType string = 'AIServices'

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

resource gpt35ModelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = {
  parent: openAIAccount
  name: '${openAIAccountName}-gpt-35-deployment'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '0125'
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    currentCapacity: 10
    raiPolicyName: 'Microsoft.Default'
  }
}

resource gpt4oModelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = {
  parent: openAIAccount
  name: '${openAIAccountName}-gpt-40-deployment'
  dependsOn: [
    gpt35ModelDeployment
  ]
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    currentCapacity: 10
    raiPolicyName: 'Microsoft.Default'
  }
}

/*resource speechDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-06-01-preview' = {
  parent: openAIAccount
  name: '${openAIAccountName}-speech-deployment'
  dependsOn: [
    gpt35ModelDeployment
  ]
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'speech'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    currentCapacity: 10
    raiPolicyName: 'Microsoft.Default'
  }
}*/