@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloud string

@description('Resource tag for Jumpstart AKS-EE-Full')
param resourceTags object = {
  Project: 'Jumpstart'
}

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the Network Security Group')
param networkSecurityGroupNameCloud string = 'AKS-EE-Full-NSG'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = 'AKS-EE-Full-NSG-Bastion'

var addressPrefixCloud = '10.16.0.0/16'
var subnetAddressPrefixInnerLoop = '10.16.64.0/21'
var bastionSubnetIpPrefix = '10.16.3.64/26'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${cloudVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = 'AKS-EE-Full-Bastion'
var bastionPublicIpAddressName = '${bastionName}-PIP'


var bastionSubnet = [
  {
    name: 'AzureBastionSubnet'
    properties: {
      addressPrefix: bastionSubnetIpPrefix
      networkSecurityGroup: {
        id: bastionNetworkSecurityGroup.id
      }
    }
  }
]

var cloudSubnet = [
  {
    name: subnetNameCloud
    properties: {
      addressPrefix: subnetAddressPrefixInnerLoop
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroupCloud.id
      }
    }
  }
]

resource cloudVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkNameCloud
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefixCloud
      ]
    }
    subnets: (deployBastion == false) ? cloudSubnet : union(cloudSubnet,bastionSubnet)
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-07-01' = if (deployBastion == true) {
  name: bastionPublicIpAddressName
  location: location
  tags: resourceTags
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource networkSecurityGroupCloud 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: networkSecurityGroupNameCloud
  location: location
  tags: resourceTags
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-07-01' = if (deployBastion == true) {
  name: bastionNetworkSecurityGroupName
  location: location
  tags: resourceTags
  properties: {
    securityRules: [
      {
        name: 'bastion_allow_https_inbound'
        properties: {
          priority: 1010
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_gateway_manager_inbound'
        properties: {
          priority: 1011
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_load_balancer_inbound'
        properties: {
          priority: 1012
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_host_comms'
        properties: {
          priority: 1013
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'bastion_allow_ssh_rdp_outbound'
        properties: {
          priority: 1014
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'bastion_allow_azure_cloud_outbound'
        properties: {
          priority: 1015
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_bastion_comms'
        properties: {
          priority: 1016
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'bastion_allow_get_session_info'
        properties: {
          priority: 1017
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
    ]
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-07-01' = if (deployBastion == true) {
  name: bastionName
  location: location
  tags: resourceTags
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          publicIPAddress: {
            id: publicIpAddress.id
          }
          subnet: {
            id: bastionSubnetRef
          }
        }
      }
    ]
  }
}

output vnetId string = cloudVirtualNetwork.id
output subnetId string = cloudVirtualNetwork.properties.subnets[0].id
output virtualNetworkNameCloud string = cloudVirtualNetwork.name
