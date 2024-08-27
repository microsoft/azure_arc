@description('The name of the IoT Hub')
param iotHubName string

@description('The location of the Iot Hub')
param location string

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('The name of the IotHub SKU')
param skuName string = 'S1'

@description('The capacity of the IotHub SKU')
param capacity int = 1

param consumerGroupName string = 'cg1'

var consumerGroup = '${iotHubName}/events/${consumerGroupName}'

resource iotHub 'Microsoft.Devices/IotHubs@2022-04-30-preview' = {
  name: iotHubName
  location: location
  tags: resourceTags
  sku: {
    name: skuName
    capacity: capacity
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: 2
      }
    }
    rootCertificate: {
      enableRootCertificateV2: true
    }
  }
}

resource iotHubConsumerGroup 'Microsoft.Devices/IotHubs/eventHubEndpoints/ConsumerGroups@2022-04-30-preview' = {
  name: consumerGroup
  properties: {
    name: consumerGroupName
  }
  dependsOn: [
    iotHub
  ]
}

output iotHubHostName string = iotHub.properties.hostName
output iotHubId string = iotHub.id
output iotHubConsumerGroup string = consumerGroupName
