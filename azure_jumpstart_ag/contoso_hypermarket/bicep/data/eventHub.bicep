@description('The name of the EventHub namespace')
param eventHubNamespaceName string = 'aiohubns${uniqueString(resourceGroup().id)}'

@description('The name of the EventHub')
param eventHubName string = 'aioEventHub'

@description('EventHub Sku')
param eventHubSku string = 'Standard'

@description('EventHub Tier')
param eventHubTier string = 'Standard'

@description('EventHub capacity')
param eventHubCapacity int = 1

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_azure_aio'
}

@description('The location of the Azure Data Explorer cluster')
param location string = resourceGroup().location

@description('The name of the Azure Data Explorer Event Hub consumer group for mqttdataemulator')
param stagingDataCGName string = 'mqttdataemulator'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: eventHubNamespaceName
  tags: resourceTags
  location: location
  sku: {
    name: eventHubSku
    capacity: eventHubCapacity
    tier: eventHubTier
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  name: eventHubName
  parent: eventHubNamespace
  properties: {
    messageRetentionInDays: 1
  }
}

resource eventHubAuthRule 'Microsoft.EventHub/namespaces/authorizationRules@2023-01-01-preview' = {
  name: 'eventHubAuthRule'
  parent: eventHubNamespace
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource weldingrobotCG 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  name: stagingDataCGName
  parent: eventHub
}

output eventHubResourceId string = eventHub.id
