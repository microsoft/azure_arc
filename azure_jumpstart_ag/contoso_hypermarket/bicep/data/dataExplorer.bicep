@description('The name of the Azure Data Explorer cluster')
param adxClusterName string

@description('The location of the Azure Data Explorer cluster')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_azure_aio'
}

@description('The name of the Azure Data Explorer cluster Sku')
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'

@description('The name of the Azure Data Explorer cluster Sku tier')
param skuTier string = 'Basic'

@description('The name of the Event Hub')
param eventHubName string

@description('The name of the Event Hub Namespace')
param eventHubNamespaceName string

@description('The resource id of the Event Hub')
param eventHubResourceId string

@description('The name of the Azure Data Explorer database')
param adxDBName string = 'manufacturing'

@description('# of nodes')
@minValue(1)
@maxValue(2)
param skuCapacity int = 1


resource adxCluster 'Microsoft.Kusto/clusters@2023-05-02' = {
  name: adxClusterName
  location: location
  tags: resourceTags
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource manufacturingAdxDB 'Microsoft.Kusto/clusters/databases@2023-05-02' = {
  parent: adxCluster
  name: adxDBName
  location: location
  kind: 'ReadWrite'
}

resource azureEventHubsDataReceiverRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
  scope: tenant()
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' existing = {
  name: '${eventHubNamespaceName}/${eventHubName}'
}

resource eventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('AzureEventHubsDataReceiverRole', adxCluster.id, eventHubResourceId)
  scope: eventHub
  properties: {
    roleDefinitionId: azureEventHubsDataReceiverRole.id
    principalId: adxCluster.identity.principalId
  }
}

output adxEndpoint string = adxCluster.properties.uri
