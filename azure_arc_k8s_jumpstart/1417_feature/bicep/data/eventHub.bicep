@description('The name of the EventHub namespace')
param eventHubNamespaceName string = 'ft1eventhubns${uniqueString(resourceGroup().id)}'

@description('The name of the EventHub')
param eventHubName string = 'Ft1EventHub'

@description('EventHub Sku')
param eventHubSku string = 'Basic'

@description('EventHub capacity')
param eventHubCapacity int = 1

@description('The location of the Azure Data Explorer cluster')
param location string = resourceGroup().location


resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventHubSku
    capacity: eventHubCapacity
    tier: 'Basic'
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  name: eventHubName
  parent: eventHubNamespace
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

output eventHubResourceId string = eventHub.id
