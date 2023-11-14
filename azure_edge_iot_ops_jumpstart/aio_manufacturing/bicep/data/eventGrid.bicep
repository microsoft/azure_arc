@description('The name of the EventGrid namespace')
param eventGridNamespaceName string = 'aioNamespace'

@description('The location of the Azure Data Explorer cluster')
param location string = resourceGroup().location

@maxLength(5)
@description('Random GUID')
param namingGuid string

@description('EventGrid Sku')
param eventGridSku string = 'Standard'

@description('EventGrid capacity')
param eventGridCapacity int = 1

@description('The name of the EventGrid client group')
param eventGridClientGroupName string = '$all'

@description('The name of the EventGrid namespace')
param eventGridTopicSpaceName string = 'aiotopicSpace${namingGuid}'

@description('The name of the EventGrid topic templates')
param eventGridTopicTemplates array = [
    '#'
]

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_azure_aio'
}

@description('The name of the EventGrid publisher binding name')
param publisherBindingName string = 'publisherBinding'

@description('The name of the EventGrid subscription binding name')
param subscriberBindingName string = 'subscriberBindingName'

@description('The name of the EventHub topic subscription')
param eventGridTopicSubscriptionName string = 'aioEventHubSubscription'

@description('The name of the storage topic subscription')
param storageTopicSubscriptionName string = 'aioStorageSubscription'

@description('The name of the EventGrid topic')
param eventGridTopicName string = 'aiotopic${namingGuid}'

@description('The name of the EventGrid topic sku')
param eventGridTopicSku string = 'Basic'

@description('The resource Id of the event hub')
param eventHubResourceId string

@description('The resource Id of the storage account queue')
param storageAccountResourceId string

@description('The name of the storage account queue')
param queueName string

@description('The time to live of the storage account queue')
param queueTTL int = 604800

@description('The maximum number of client sessions per authentication name')
param maximumClientSessionsPerAuthenticationName int = 100

resource eventGrid 'Microsoft.EventGrid/namespaces@2023-06-01-preview' = {
  name: eventGridNamespaceName
  tags: resourceTags
  location: location
  sku: {
    name: eventGridSku
    capacity: eventGridCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    topicSpacesConfiguration: {
      state: 'Enabled'
      maximumClientSessionsPerAuthenticationName: maximumClientSessionsPerAuthenticationName
      clientAuthentication: {
        alternativeAuthenticationNameSources: [
          'ClientCertificateSubject'
        ]
      }
      routeTopicResourceId: eventGridTopic.id
    }
  }
}

resource eventGridTopicSpace 'Microsoft.EventGrid/namespaces/topicSpaces@2023-06-01-preview' = {
  name: eventGridTopicSpaceName
  parent: eventGrid
  properties: {
    topicTemplates: eventGridTopicTemplates
  }
}

resource eventGridPubisherBinding 'Microsoft.EventGrid/namespaces/permissionBindings@2023-06-01-preview' = {
  name: publisherBindingName
  parent: eventGrid
  properties: {
    clientGroupName: eventGridClientGroupName
    permission: 'Publisher'
    topicSpaceName: eventGridTopicSpace.name
  }
}

resource eventGridsubscriberBindingName 'Microsoft.EventGrid/namespaces/permissionBindings@2023-06-01-preview' = {
  name: subscriberBindingName
  parent: eventGrid
  properties: {
    clientGroupName: eventGridClientGroupName
    permission: 'Subscriber'
    topicSpaceName: eventGridTopicSpace.name
  }
}

resource eventGridTopic 'Microsoft.EventGrid/topics@2023-06-01-preview' = {
  name: eventGridTopicName
  location: location
  tags: resourceTags
  sku: {
    name: eventGridTopicSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
  }
}


resource eventHubTopicSubscription 'Microsoft.EventGrid/topics/eventSubscriptions@2023-06-01-preview' = {
  name: eventGridTopicSubscriptionName
  parent:eventGridTopic
  properties: {
    destination: {
      endpointType: 'EventHub'
      properties: {
        resourceId: eventHubResourceId
      }
    }
    filter: {
      enableAdvancedFilteringOnArrays: true
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
  }
}

resource storageTopicSubscription 'Microsoft.EventGrid/topics/eventSubscriptions@2023-06-01-preview' = {
  name: storageTopicSubscriptionName
  parent:eventGridTopic
  properties: {
    destination: {
      endpointType: 'StorageQueue'
      properties: {
        resourceId: storageAccountResourceId
        queueName: queueName
        queueMessageTimeToLiveInSeconds: queueTTL
      }
    }
    filter: {
      enableAdvancedFilteringOnArrays: true
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
  }
}


resource azureEventGridDataSenderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'd5a91429-5739-47e2-a06b-3470a27159e7'
  scope: tenant()
}

resource eventGridTopicRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('azureEventGridDataSenderRole', eventGrid.id, eventGridTopic.id)
  scope: eventGridTopic
  properties: {
    roleDefinitionId: azureEventGridDataSenderRole.id
    principalId: eventGrid.identity.principalId
  }
}

