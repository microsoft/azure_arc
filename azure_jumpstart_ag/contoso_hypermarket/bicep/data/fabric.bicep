@description('Microsoft Fabric capacity name')
param fabricCapacityName string = 'agorafabric'

@description('The location of the Microsoft Fabric capacity ')
param location string = resourceGroup().location

@description('Microsoft Fabric capacity admin email address')
param fabricCapacityAdmin string

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: fabricCapacityName
  location: location
  sku: {
    name: 'F2'
    tier: 'Fabric'
  }
  properties: {
    administration: {
        members: [fabricCapacityAdmin]
    }
  }
}
