@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string

@description('Name of the stores VNet')
param virtualNetworkNameStores string

@description('Name of the prod AKS subnet in the cloud virtual network')
param subnetNameCloudAksProd string

@description('Name of the dev AKS subnet in the cloud virtual network')
param subnetNameCloudAksDev string

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloudAksInnerLoop string

@description('Name of the New York subnet subnet in the stores virtual network')
param subnetNameStoresNewYork string

@description('Name of the Chicago subnet subnet in the stores virtual network')
param subnetNameStoresChicago string

@description('Name of the Boston subnet subnet in the stores virtual network')
param subnetNameStoresBoston string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the prod Network Security Group')
param networkSecurityGroupNameCloud string = 'Agora-Cloud-NSG'

@description('Name of the stores Network Security Group')
param networkSecurityGroupNameStores string = 'Agora-Stores-NSG'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = 'Agora-Bastion-NSG'

var addressPrefixCloud = '10.16.0.0/16'
var subnetAddressPrefixAksProd = '10.16.72.0/21'
var subnetAddressPrefixAksDev = '10.16.80.0/21'
var subnetAddressPrefixInnerLoop = '10.16.64.0/21'
var addressPrefixStores = '10.18.0.0/16'
var subnetAddressPrefixNewYork = '10.18.72.0/21'
var subnetAddressPrefixChicago = '10.18.80.0/21'
var subnetAddressPrefixBoston = '10.18.64.0/21'
var bastionSubnetIpPrefix = '10.16.3.64/26'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${cloudVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = 'Agora-Bastion'
var bastionPublicIpAddressName = '${bastionName}-PIP'
var networkPeeringCloudToStores = 'networkPeeringCloudToStores'
var networkPeeringStoresToCloud = 'networkPeeringStoresToCloud'

var cloudAKSProdSubnet = [
  {
    name: subnetNameCloudAksProd
    properties: {
      addressPrefix: subnetAddressPrefixAksProd
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroupCloud.id
      }
    }
  }
]
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
var cloudAKSDevSubnet = [
  {
    name: subnetNameCloudAksDev
    properties: {
      addressPrefix: subnetAddressPrefixAksDev
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroupCloud.id
      }
    }
  }
]

var cloudAKSInnerLoopSubnet = [
  {
    name: subnetNameCloudAksInnerLoop
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

resource cloudVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: virtualNetworkNameCloud
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefixCloud
      ]
    }
    subnets: (deployBastion == false) ? union (cloudAKSProdSubnet,cloudAKSDevSubnet,cloudAKSInnerLoopSubnet) : union(cloudAKSProdSubnet,cloudAKSDevSubnet,cloudAKSInnerLoopSubnet,bastionSubnet)
  }
}

resource storesVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: virtualNetworkNameStores
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefixStores
      ]
    }
    subnets: [
      {
        name: subnetNameStoresNewYork
        properties: {
          addressPrefix: subnetAddressPrefixNewYork
          networkSecurityGroup: {
            id: networkSecurityGroupStores.id
          }
        }
      }
      {
        name: subnetNameStoresChicago
        properties: {
          addressPrefix: subnetAddressPrefixChicago
          networkSecurityGroup: {
            id: networkSecurityGroupStores.id
          }
        }
      }
      {
        name: subnetNameStoresBoston
        properties: {
          addressPrefix: subnetAddressPrefixBoston
          networkSecurityGroup: {
            id: networkSecurityGroupStores.id
          }
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-01-01' = if (deployBastion == true) {
  name: bastionPublicIpAddressName
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



resource networkSecurityGroupCloud 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: networkSecurityGroupNameCloud
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow_k8s_80'
        properties: {
          priority: 1003
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'allow_k8s_8080'
        properties: {
          priority: 1004
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'allow_k8s_443'
        properties: {
          priority: 1005
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource networkSecurityGroupStores 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: networkSecurityGroupNameStores
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow_k8s_80'
        properties: {
          priority: 1003
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'allow_k8s_8080'
        properties: {
          priority: 1004
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'allow_k8s_443'
        properties: {
          priority: 1005
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-01-01' = if (deployBastion == true) {
  name: bastionNetworkSecurityGroupName
  location: location
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

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = if (deployBastion == true) {
  name: bastionName
  location: location
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

resource peeringCloudToStores 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${virtualNetworkNameCloud}-peering-to-stores-vnet'
  properties: {
    remoteVirtualNetwork:{
      id: storesVirtualNetwork.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource peeringStoresToCloud 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${virtualNetworkNameStores}-peering-to-cloud-vnet'
  properties: {
    remoteVirtualNetwork:{
      id: cloudVirtualNetwork.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

output vnetId string = cloudVirtualNetwork.id
output CloudSubnetId string = cloudVirtualNetwork.properties.subnets[0].id
output virtualNetworkNameCloud string = cloudVirtualNetwork.name
output innerLoopSubnetId string = cloudVirtualNetwork.properties.subnets[0].id
