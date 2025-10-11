@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string

@description('Name of the K3s subnet in the cloud virtual network')
param subnetNameCloudK3s string

@description('Name of the inner-loop subnet in the cloud virtual network')
param subnetNameCloud string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the prod Network Security Group')
param networkSecurityGroupNameCloud string = 'Ag-NSG-Prod'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = 'Ag-NSG-Bastion'

@description('Name of the NAT Gateway')
param natGatewayName string = 'Ag-NatGateway'

var addressPrefixCloud = '10.16.0.0/16'
var subnetAddressPrefixK3s = '10.16.80.0/21'
var subnetAddressPrefixCloud = '10.16.64.0/21'
var bastionSubnetIpPrefix = '10.16.3.64/26'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${cloudVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = 'Ag-Bastion'
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
var cloudK3sSubnet = [
  {
    name: subnetNameCloudK3s
    properties: {
      addressPrefix: subnetAddressPrefixK3s
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroupCloud.id
      }
      natGateway: {
        id: natGateway.id
      }
      defaultOutboundAccess: false
    }
  }
]

var cloudSubnet = [
  {
    name: subnetNameCloud
    properties: {
      addressPrefix: subnetAddressPrefixCloud
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroupCloud.id
      }
      natGateway: deployBastion
        ? {
            id: natGateway.id
          }
        : null
      defaultOutboundAccess: false
    }
  }
]

resource cloudVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkNameCloud
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefixCloud
      ]
    }
    subnets: (deployBastion == false)
      ? union(cloudK3sSubnet, cloudSubnet)
      : union(cloudK3sSubnet, cloudSubnet, bastionSubnet)
    //subnets: (deployBastion == false) ? union (cloudAKSDevSubnet,cloudAKSInnerLoopSubnet) : union(cloudAKSDevSubnet,cloudAKSInnerLoopSubnet,bastionSubnet)
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-02-01' = if (deployBastion == true) {
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

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: '${natGatewayName}-PIP'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natGatewayPublicIp.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
}

resource networkSecurityGroupCloud 'Microsoft.Network/networkSecurityGroups@2023-02-01' = {
  name: networkSecurityGroupNameCloud
  location: location
  tags: resourceTags
  properties: {
    securityRules: [
      // intentionally empty since user will add rule to RDP or will use JIT
    ]
  }
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-02-01' = if (deployBastion == true) {
  name: bastionNetworkSecurityGroupName
  location: location
  tags: resourceTags
  properties: {
    securityRules: [
      {
        name: 'bastion_allow_https_inbound'
        properties: {
          priority: 210
          protocol: 'TCP'
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
          priority: 211
          protocol: 'TCP'
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
          priority: 212
          protocol: 'TCP'
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
          priority: 213
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
          priority: 214
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
          priority: 215
          protocol: 'TCP'
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
          priority: 216
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
          priority: 217
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

resource bastionHost 'Microsoft.Network/bastionHosts@2023-02-01' = if (deployBastion == true) {
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
output k3sSubnetId string = cloudVirtualNetwork.properties.subnets[0].id
output innerLoopSubnetId string = cloudVirtualNetwork.properties.subnets[1].id
output virtualNetworkNameCloud string = cloudVirtualNetwork.name
