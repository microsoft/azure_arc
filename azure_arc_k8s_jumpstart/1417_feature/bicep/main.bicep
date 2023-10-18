@description('The name of you Virtual Machine.')
param vmName string = 'AKS-EE-Demo'

@description('Kubernetes distribution')
@allowed([
  'k8s'
  'k3s'
])
param kubernetesDistribution string = 'k3s'

@description('Username for the Virtual Machine.')
param windowsAdminUsername string = 'arcdemo'

@description('Windows password for the Virtual Machine')
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources.')
@allowed([
  'westus3'
  'eastus2'
  'westeurope'
  'centraluseuap'
  'eastus2euap'
])
param location string

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool

@description('the Azure Bastion host name')
param bastionHostName string = 'AKS-EE-Demo-Bastion'

@description('The size of the VM')
param vmSize string = 'Standard_D8s_v3'

@description('Unique SPN app ID')
param spnClientId string

@description('Unique SPN password')
@minLength(12)
@maxLength(123)
@secure()
param spnClientSecret string

@description('Unique SPN tenant ID')
param spnTenantId string

@description('Azure subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = '1417-feature-br'

@description('Name of the VNET')
param virtualNetworkName string = 'AKS-EE-Demo-VNET'

@description('Name of the subnet in the virtual network')
param subnetName string = 'Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'AKS-EE-Demo-NSG'
param resourceTags object = {
  Project: 'jumpstart_azure_ft1'
}

@maxLength(5)
@description('Random GUID')
param namingGuid string = toLower(substring(newGuid(), 0, 5))

@description('Deploy Windows Node for AKS Edge Essentials')
param windowsNode bool = false

@description('Name of the storage account')
param ft1StorageAccountName string = 'ft1stg${namingGuid}'

@description('Name of the storage queue')
param storageQueueName string = 'ft1queue'

@description('Name of the event hub')
param eventHubName string = 'ft1hub${namingGuid}'

@description('Name of the event hub namespace')
param eventHubNamespaceName string = 'ft1hubns${namingGuid}'

@description('Name of the event grid namespace')
param eventGridNamespaceName string = 'ft1eventgridns${namingGuid}'

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string = 'ft1adx${namingGuid}'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_arc_k8s_jumpstart/1417_feature/bicep/'
var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var bastionSubnetName = 'AzureBastionSubnet'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var bastionSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, bastionSubnetName)
var osDiskType = 'Premium_LRS'
var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'
var bastionName = concat(bastionHostName)
var bastionSubnetIpPrefix = '10.1.1.64/26'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: networkInterfaceName
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
          publicIPAddress: ((!deployBastion) ? PublicIPNoBastion : null)
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
}

resource networkSecurityGroupName_allow_RDP_3389 'Microsoft.Network/networkSecurityGroups/securityRules@2022-05-01' = if (deployBastion) {
  parent: networkSecurityGroup
  name: 'allow_RDP_3389'
  properties: {
    priority: 1001
    protocol: 'TCP'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefix: bastionSubnetIpPrefix
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '3389'
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
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
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetIpPrefix
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2022-07-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: ((!deployBastion) ? 'Basic' : 'Standard')
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'fromImage'
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
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
  }
}

resource Bootstrap 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: vm
  name: 'Bootstrap'
  location: location
  tags: {
    displayName: 'Run Bootstrap'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/PowerShell/Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -spnClientId ${spnClientId} -spnClientSecret ${spnClientSecret} -spnTenantId ${spnTenantId} -subscriptionId ${subscriptionId} -resourceGroup ${resourceGroup().name} -location ${location} -kubernetesDistribution ${kubernetesDistribution} -windowsNode ${windowsNode} -templateBaseUrl ${templateBaseUrl}'
    }
  }
}

resource InstallWindowsFeatures 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: vm
  name: 'InstallWindowsFeatures'
  dependsOn: [
    Bootstrap
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: uri(templateBaseUrl, 'artifacts/Settings/DSCInstallWindowsFeatures.zip')
        script: 'DSCInstallWindowsFeatures.ps1'
        function: 'InstallWindowsFeatures'
      }
    }
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-07-01' = if (deployBastion) {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetRef
          }
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork

  ]
}

module storageAccount 'storage/storageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    storageAccountName: ft1StorageAccountName
    location: location
    storageQueueName: storageQueueName
  }
}

module eventHub 'data/eventHub.bicep' = {
  name: 'eventHub'
  params: {
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
    location: location
  }
}

module eventGrid 'data/eventGrid.bicep' = {
  name: 'eventGrid'
  params: {
    eventGridNamespaceName: eventGridNamespaceName
    eventHubResourceId: eventHub.outputs.eventHubResourceId
    queueName: storageQueueName
    storageAccountResourceId: storageAccount.outputs.storageAccountId
    location: location
  }
}

module adxCluster 'data/dataExplorer.bicep' = {
  name: 'dataExplorer'
  params: {
    adxClusterName: adxClusterName
    location: location
  }
}

output windowsAdminUsername string = windowsAdminUsername
output publicIP string = concat(publicIpAddress.properties.ipAddress)
