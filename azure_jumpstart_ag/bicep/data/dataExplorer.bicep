@description('The name of the Azure Data Explorer cluster')
param adxClusterName string

@description('The location of the Azure Data Explorer cluster')
param location string

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('The name of the Azure Data Explorer cluster Sku')
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'

@description('The name of the Azure Data Explorer cluster Sku tier')
param skuTier string = 'Basic'

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string

@description('The ID of the IoT Hub')
param iotHubId string

@description('The name of the IoT Hub consumer group')
param iotHubConsumerGroup string

@description('The Name of the Cosmos DB account')
param cosmosDBAccountName string

@description('# of nodes')
@minValue(1)
@maxValue(2)
param skuCapacity int = 1

//  Id of the Cosmos DB data reader role
var cosmosDataReader = '00000000-0000-0000-0000-000000000001'
var cosmosDBAccountReader = 'fbdf93bf-df7d-467e-a4d2-9458aa1360c8'

resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDBAccountName
}

resource adxCluster 'Microsoft.Kusto/clusters@2023-05-02' = {
  name: adxClusterName
  location: location
  tags: resourceTags
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
  }

  // Assign system assigned identity
  identity: {
    type: 'SystemAssigned'
  }

  // Wait until Cosmos DB account is created to assign role permissions and create connection
  dependsOn: [
    cosmosDBAccount
  ]
}

resource ordersScript 'Microsoft.Kusto/clusters/databases/scripts@2023-05-02' = {
  name: 'ordersScrit'
  parent: posOrdersDB
  properties: {
    continueOnErrors: false
    forceUpdateTag: 'string'
    scriptContent: loadTextContent('script.kql')
  }
}

resource posOrdersDB 'Microsoft.Kusto/clusters/databases@2023-05-02' = {
  parent: adxCluster
  name: posOrdersDBName
  location: location
  kind: 'ReadWrite'
}

resource adxdatabaseIotConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2022-02-01' = {
  name: 'iotHubConnection'
  location: location
  kind: 'IotHub'
  parent: posOrdersDB
  properties: {
    iotHubResourceId: iotHubId
    consumerGroup: iotHubConsumerGroup
    sharedAccessPolicyName: 'iothubowner'
    tableName: 'environmentSensor'
    dataFormat: 'JSON'
    eventSystemProperties: [
      'iothub-enqueuedtime'
      'iothub-connection-device-id'
      'iothub-creation-time-utc'
    ]
    mappingRuleName: 'EnvironmentSensorMapping'
  }
}

//  We need to authorize the cluster to read Cosmos DB's change feed by assigning the role
resource clusterCosmosDbAuthorization 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  name: guid(adxCluster.id, cosmosDBAccountName)
  parent: cosmosDBAccount
  properties: {
    principalId: adxCluster.identity.principalId
    roleDefinitionId: resourceId('Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions', cosmosDBAccountName, cosmosDataReader)
    scope: resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosDBAccountName)
  }
}

resource cosmosReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: cosmosDBAccountReader
}

// Assign "Cosmos DB Account Reader Role"
resource cosmosDBAccountReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(adxCluster.id, cosmosDBAccountName, cosmosDBAccountReader)
  properties: {
    roleDefinitionId: cosmosReaderRoleDefinition.id
    principalId: adxCluster.identity.principalId
    scope: resourceGroup().id
  }
}

resource ordersConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2023-05-02' = {
  location: location
  name: 'OrdersConnection'
  parent: posOrdersDB

  //  Here we need to explicitely declare dependencies
  //  Since we do not use those resources in the event connection
  //  but we do need them to be deployed first
  dependsOn: [
    //  We need the table to be present in the database
    ordersScript

    //  We need the cluster to be receiver on the Event Hub
    clusterCosmosDbAuthorization
    cosmosDBAccountReaderRoleAssignment
  ]

  kind: 'CosmosDb'
  properties: {
    tableName: 'Orders'
    mappingRuleName: 'OrdersMapping'
    managedIdentityResourceId: adxCluster.id
    cosmosDbAccountResourceId: cosmosDBAccount.id
    cosmosDbDatabase: posOrdersDBName
    cosmosDbContainer: 'Orders'
  }
}
