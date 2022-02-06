@description('The name of you Virtual Machine.')
param vmName string = 'Arc-Win-Demo'

@description('Username for the Virtual Machine.')
param adminUsername string = 'arcdemo'

@description('Windows password for the Virtual Machine')
@secure()
param adminPassword string 

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources.')
param location string = 'eastus'

@description('The size of the VM')
param vmSize string = 'Standard_D8s_v3'

@description('Unique SPN app ID')
param appId string

@description('Unique SPN password')
param password string

@description('Unique SPN tenant ID')
param tenantId string

@description('Azure resource group')
param resourceGroup string

@description('Azure subscription ID')
param subscriptionId string

@description('Name of the VNET')
param virtualNetworkName string = 'Arc-Win-Demo-VNET'

@description('Name of the subnet in the virtual network')
param subnetName string = 'Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'Arc-Win-Demo-NSG'
param resourceTags object = {
  Project: 'jumpstart_azure_arc_servers'
}

var vmName_var = concat(vmName)
var publicIpAddressName_var = '${vmName}-PIP'
var networkInterfaceName_var = '${vmName}-NIC'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var osDiskType = 'Premium_LRS'
var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'

resource networkInterfaceName 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: networkInterfaceName_var
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddressName.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupName_resource.id
    }
  }
  dependsOn: [
    virtualNetworkName_resource
  ]
}

resource networkSecurityGroupName_resource 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow_RDP_3389'
        properties: {
          priority: 1001
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2019-04-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource publicIpAddressName 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpAddressName_var
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
}

resource vmName_resource 'Microsoft.Compute/virtualMachines@2019-03-01' = {
  name: vmName_var
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName_var}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName.id
        }
      ]
    }
    osProfile: {
      computerName: vmName_var
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
  }
}

resource vmName_ClientTools 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vmName_resource
  name: 'ClientTools'
  location: location
  tags: {
    displayName: 'Install Arc Agent'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_arc_servers_jumpstart/azure/windows/arm_template/scripts/install_arc_agent.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File install_arc_agent.ps1 -appId ${appId} -password ${password} -tenantId ${tenantId} -resourceGroup ${resourceGroup} -subscriptionId ${subscriptionId} -location ${location} -adminUsername ${adminUsername}'
    }
  }
}

output adminUsername string = adminUsername
output publicIP string = concat(publicIpAddressName.properties.ipAddress)
