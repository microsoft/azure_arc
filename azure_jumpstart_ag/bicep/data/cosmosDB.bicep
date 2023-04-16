
@description('The name of the Cosmos DB')
param accountName string

@description('The location of the Cosmos DB')
param location string

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string = 'posOrders'

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2023-03-01-preview' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource posOrdersDB 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  parent: cosmosDB
  name: posOrdersDBName
  properties: {
    options: {}
    resource: {
      id: posOrdersDBName
    }
  }
}

resource posOrdersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  parent: posOrdersDB
  name: 'orders'
  properties: {
    options: {
      autoscaleSettings: {
        maxThroughput: 4000
      }
    }
    resource: {
      id: 'orders'
      partitionKey: {
        paths: [
          '/orderID'
        ]
        kind: 'Hash'
      }
    }
  }
}
