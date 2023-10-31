@description('The name of the EventGrid namespace')
param eventGridNamespaceName string = 'Ft1Namespace'

@description('The location of the Azure Data Explorer cluster')
param location string = 'westus2'

@maxLength(5)
@description('Random GUID')
param namingGuid string

@description('EventGrid Sku')
param eventGridSku string = 'Standard'

@description('EventGrid capacity')
param eventGridCapacity int = 1

@description('The name of the EventGrid client group')
param eventGridClientGroupName string = '$all'

@description('The name of the EventGrid client')
param eventGridClientName string = 'client1'

@description('The name of the EventGrid client authentication property')
param eventGridAuthName string = 'client1-auth'

@description('The EventGrid client authentication thumbprint')
param eventGridAuthThumbprint array = [
  '46c9ef363ec21993f8a45dbf2d14494e78e3550a8f33b673d5b3863a05ac4d5f'
]

@description('The EventGrid client authentication validation scheme')
param authValidationSchema string = 'ThumbprintMatch'

@description('The name of the EventGrid namespace')
param eventGridTopicSpaceName string = 'ft1topicSpace${namingGuid}'

@description('The name of the EventGrid topic templates')
param eventGridTopicTemplates array = [
    'contoso/magnemotion'
    'contoso/productionline'
]

@description('The name of the EventGrid publisher binding name')
param publisherBindingName string = 'publisherBinding'

@description('The name of the EventGrid subscription binding name')
param subscriberBindingName string = 'subscriberBindingName'

@description('The name of the EventHub topic subscription')
param eventGridTopicSubscriptionName string = 'ft1EventHubSubscription'

@description('The name of the storage topic subscription')
param storageTopicSubscriptionName string = 'ft1StorageSubscription'

@description('The name of the EventGrid topic')
param eventGridTopicName string = 'ft1topic${namingGuid}'

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
      routingEnrichments: {
        static: [
          {
            key: 'indicator'
            valueType: 'string'
          }
        ]
      }
    }
  }
}

resource eventGridClient 'Microsoft.EventGrid/namespaces/clients@2023-06-01-preview' = {
  name:eventGridClientName
  parent:eventGrid
  properties: {
    authenticationName: eventGridAuthName
    clientCertificateAuthentication: {
      allowedThumbprints: eventGridAuthThumbprint
      validationScheme: authValidationSchema
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
  sku: {
    name: eventGridTopicSku
  }
  identity: {
    type: 'SystemAssigned'
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
