@description('The name of the Azure Data Explorer cluster')
param ClusterName string

@description('The location of the Azure Data Explorer cluster')
param location string

@description('The name of the Azure Data Explorer cluster Sku')
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'

@description('The name of the Azure Data Explorer cluster Sku tier')
param skuTier string = 'Basic'

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string = 'posOrders'

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
