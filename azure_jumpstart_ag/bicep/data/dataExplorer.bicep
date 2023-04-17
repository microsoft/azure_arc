@description('The name of the Azure Data Explorer cluster')
param ClusterName string = 'agadx${namingGuid}'

@description('The location of the Azure Data Explorer cluster')
param location string

@description('The name of the Azure Data Explorer cluster Sku')
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'

@description('The name of the Azure Data Explorer cluster Sku tier')
param skuTier string = 'Basic'

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string = 'posOrders'

@description('The GUID used for naming')
param namingGuid string

@description('The ID of the IoT Hub')
param iotHubId string

@description('The name of the IoT Hub consumer group')
param iotHubConsumerGroup string

resource adx 'Microsoft.Kusto/clusters@2022-12-29' = {
  name: ClusterName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
}

resource posOrdersDB 'Microsoft.Kusto/clusters/databases@2022-12-29' = {
  parent: adx
  name: posOrdersDBName
  location: location
  kind: 'ReadWrite'
}

resource iotHubConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2022-12-29' ={
  parent: posOrdersDB
  kind: 'IotHub'
  name: 'IoTHub'
  location: location
  properties: {
    consumerGroup: iotHubConsumerGroup
    iotHubResourceId: iotHubId
    sharedAccessPolicyName: 'iothubowner'
  }
}
