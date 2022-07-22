@description('Name of the VNet')
param virtualNetworkName string = 'HciBox-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'HciBox-Subnet'

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'HciBox-NSG'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = 'HciBox-Bastion-NSG'

var addressPrefix = '172.16.0.0/16'
var subnetAddressPrefix = '172.16.1.0/24'
var mgmtSubnetName = 'ManagementSubnet'
var mgmtSubnetAddressPrefix = '172.16.100.0/24'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${arcVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = 'HciBox-Bastion'
var bastionSubnetIpPrefix = '172.16.3.64/26'
var bastionPublicIpAddressName = '${bastionName}-PIP'

resource arcVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: (deployBastion) == true ? [
      subnet
      subnetBastion
      subnetMgmt
    ] : [
      subnet
      subnetMgmt
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource subnetMgmt 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  name: mgmtSubnetName
  properties: {
    addressPrefix: mgmtSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  name: bastionSubnetName
  properties: {
    addressPrefix: bastionSubnetIpPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: bastionNetworkSecurityGroup.id
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: networkSecurityGroupName
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
      {
        name: 'allow_k8s_kubelet'
        properties: {
          priority: 1006
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '10250'
        }
      }
      {
        name: 'allow_traefik_lb_external'
        properties: {
          priority: 1007
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '32323'
        }
      }
      {
        name: 'allow_SQLMI_traffic'
        properties: {
          priority: 1008
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '11433'
        }
      }
      {
        name: 'allow_Postgresql_traffic'
        properties: {
          priority: 1009
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '15432'
        }
      }
    ]
  }
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-05-01' = if (deployBastion == true) {
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

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (deployBastion == true) {
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

resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = if (deployBastion == true) {
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

output vnetId string = arcVirtualNetwork.id
output subnetId string = arcVirtualNetwork.properties.subnets[0].id
