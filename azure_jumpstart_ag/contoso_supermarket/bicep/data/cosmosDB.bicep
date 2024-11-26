
@description('The name of the Cosmos DB')
param accountName string

@description('The location of the Cosmos DB')
param location string

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  location: location
  tags: resourceTags
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

  resource cosmosDbDatabase 'sqlDatabases' = {
    name: posOrdersDBName
    properties: {
      resource: {
        id: posOrdersDBName
      }
    }

    resource cosmosDbContainer 'containers' = {
      name: 'Orders'
      properties: {
        resource: {
          id: 'Orders'
          partitionKey: {
            kind: 'Hash'
            paths: [
              '/OrderId'
            ]
          }
        }
      }
    }
  }
}

output cosmosDBEndpoint string = cosmosDB.properties.documentEndpoint
