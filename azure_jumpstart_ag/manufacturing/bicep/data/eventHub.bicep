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

@description('The name of the Azure Data Explorer Event Hub consumer group')
param eventHubConsumerGroupName string = 'aioConsumerGroup'

@description('The name of the Azure Data Explorer Event Hub production line consumer group')
param eventHubConsumerGroupNamePl string = 'aioConsumerGroupPl'

@description('The name of the Azure Data Explorer Event Hub manufacturing consumer group')
param eventHubManufacturingCGName string = 'cgmanufacturing'



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

resource eventHubConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  name: eventHubConsumerGroupName
  parent: eventHub
}

resource eventHubConsumerGroupPl 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  name: eventHubConsumerGroupNamePl
  parent: eventHub
}

resource eventHubCGManufacturing 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = {
  name: eventHubManufacturingCGName
  parent: eventHub
}

output eventHubResourceId string = eventHub.id
