@description('Name of the VNet')
param virtualNetworkName string = '${namingPrefix}-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = '${namingPrefix}-Subnet'

@description('Name of the subnet in the virtual network')
param aksSubnetName string = '${namingPrefix}-AKS-Subnet'

@description('Name of the Domain Controller subnet in the virtual network')
param dcSubnetName string = '${namingPrefix}-DC-Subnet'

@description('Name of the DR VNet')
param drVirtualNetworkName string = '${namingPrefix}-DR-VNet'

@description('Name of the DR subnet in the DR virtual network')
param drSubnetName string = '${namingPrefix}-DR-Subnet'

@description('Name for your log analytics workspace')
param workspaceName string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'ITPro'
  'DevOps'
  'DataOps'
])
param flavor string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('SKU, leave default pergb2018')
param sku string = 'pergb2018'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Bastion host Sku name')
@allowed([
  'Basic'
  'Standard'
  'Developer'
])
param bastionSku string = 'Basic'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = '${namingPrefix}-NSG'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = '${namingPrefix}-Bastion-NSG'

@description('DNS Server configuration')
param dnsServers array = []

@description('Tags to assign for all ArcBox resources')
param resourceTags object = {
  Solution: 'jumpstart_arcbox'
}

@maxLength(7)
@description('The naming prefix for the nested virtual machines. Example: ArcBox-Win2k19')
param namingPrefix string = 'ArcBox'

var keyVaultName = toLower('${namingPrefix}${uniqueString(resourceGroup().id)}')

var security = {
  name: 'Security(${workspaceName})'
  galleryName: 'Security'
}

var subnetAddressPrefix = '10.16.1.0/24'
var addressPrefix = '10.16.0.0/16'
var aksSubnetPrefix = '10.16.76.0/22'
var dcSubnetPrefix = '10.16.2.0/24'
var drAddressPrefix = '172.16.0.0/16'
var drSubnetPrefix = '172.16.128.0/17'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = '${arcVirtualNetwork.id}/subnets/${bastionSubnetName}'
var bastionName = '${namingPrefix}-Bastion'
var bastionSubnetIpPrefix = '10.16.3.64/26'
var bastionPublicIpAddressName = '${bastionName}-PIP'
var primarySubnet = [
  {
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
]
var bastionSubnet = bastionSku != 'Developer' ? [
  {
    name: 'AzureBastionSubnet'
    properties: {
      addressPrefix: bastionSubnetIpPrefix
      networkSecurityGroup: {
        id: bastionNetworkSecurityGroup.id
      }
    }
  }
] : []
var dataOpsSubnets = [
  {
    name: aksSubnetName
    properties: {
      addressPrefix: aksSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroup.id
      }
    }
  }
  {
    name: dcSubnetName
    properties: {
      addressPrefix: dcSubnetPrefix
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
      networkSecurityGroup: {
        id: networkSecurityGroup.id
      }
    }
  }
]

resource arcVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: virtualNetworkName
  location: location
  dependsOn: [
    policyDeployment
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: (deployBastion == false && flavor != 'DataOps') ? primarySubnet : (deployBastion == false && flavor == 'DataOps') ? union(primarySubnet,dataOpsSubnets) : (deployBastion == true && flavor != 'DataOps') ? union(primarySubnet,bastionSubnet) : (deployBastion == true && flavor == 'DataOps') ? union(primarySubnet,bastionSubnet,dataOpsSubnets) : primarySubnet
  }
}

resource drVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = if (flavor == 'DataOps') {
  name: drVirtualNetworkName
  location: location
  dependsOn: [
    policyDeployment
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        drAddressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [
      {
        name: drSubnetName
        properties: {
          addressPrefix: drSubnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource virtualNetworkName_peering_to_DR_vnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = if (flavor == 'DataOps') {
  parent: arcVirtualNetwork
  name: 'peering-to-DR-vnet'
  dependsOn: [
    policyDeployment
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: drVirtualNetwork.id
    }
  }
}

resource drVirtualNetworkName_peering_to_primary_vnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = if (flavor == 'DataOps') {
  parent: drVirtualNetwork
  name: 'peering-to-primary-vnet'
  dependsOn: [
    policyDeployment
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: arcVirtualNetwork.id
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: networkSecurityGroupName
  location: location
  dependsOn: [
    policyDeployment
  ]
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
      {
        name: 'allow_SQLMI_mirroring_traffic'
        properties: {
          priority: 1012
          protocol: 'TCP'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '5022'
        }
      }
    ]
  }
}

resource bastionNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-01-01' = if (deployBastion == true) {
  name: bastionNetworkSecurityGroupName
  location: location
  dependsOn: [
    policyDeployment
  ]
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


resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: sku
    }
  }
}

resource securityGallery 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: security.name
  location: location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: security.name
    promotionCode: ''
    product: 'OMSGallery/${security.galleryName}'
    publisher: 'Microsoft'
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-01-01' = if (deployBastion == true) {
  name: bastionPublicIpAddressName
  location: location
  dependsOn: [
    policyDeployment
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-11-01' = if (deployBastion == true) {
  name: bastionName
  location: location
  dependsOn: [
    policyDeployment
  ]
  sku: {
    name: bastionSku
  }
  properties: {
    virtualNetwork: bastionSku == 'Developer' ? {
      id: arcVirtualNetwork.id
    } : null
    ipConfigurations: bastionSku != 'Developer' ? [
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
    ] : null
  }
}

module policyDeployment './policyAzureArc.bicep' = {
  name: 'policyDeployment'
  params: {
    azureLocation: location
    logAnalyticsWorkspaceId: workspace.id
    flavor: flavor
    resourceTags: resourceTags
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.5.1' = {
  name: 'keyVaultDeployment'
  dependsOn: [
    policyDeployment
  ]
  params: {
    name: toLower(keyVaultName)
    enablePurgeProtection: false
    enableSoftDelete: true
    location: location
  }
}

output vnetId string = arcVirtualNetwork.id
output subnetId string = arcVirtualNetwork.properties.subnets[0].id
