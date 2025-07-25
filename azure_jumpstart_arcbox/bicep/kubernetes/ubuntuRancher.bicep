@description('The name of you Virtual Machine')
param vmName string = '${namingPrefix}-K3s'

@description('Username for the Virtual Machine')
param adminUsername string = 'arcdemo'

@description('RSA public key used for securing SSH access to ArcBox resources. This parameter is only needed when deploying the DataOps or DevOps flavors.')
@secure()
param sshRSAPublicKey string = ''

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version')
@allowed([
  '22_04-lts-gen2'
])
param ubuntuOSVersion string = '22_04-lts-gen2'

@description('Location for all resources.')
param azureLocation string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_B4ms'

@description('Resource Id of the subnet in the virtual network')
param subnetId string

@description('Name for the staging storage account using to hold kubeconfig. This value is passed into the template as an output from mgmtStagingStorage.json')
param stagingStorageAccountName string

@description('Name of the Log Analytics workspace used with cluster extensions')
param logAnalyticsWorkspace string

@description('The base URL used for accessing artifacts and automation artifacts')
param templateBaseUrl string

@description('Storage account container name for artifacts')
param storageContainerName string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'ITPro'
  'DevOps'
  'DataOps'
])
param flavor string

@maxLength(7)
@description('The naming prefix for the nested virtual machines. Example: ArcBox-Win2k19')
param namingPrefix string = 'ArcBox'

var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var k3sControlPlane = 'true' // deploy single-node k3s control plane
var diskSize = (flavor == 'DataOps') ? 512 : 64
var numberOfIPAddresses = (flavor == 'DataOps') ? 8 : 5 // The number of IP addresses to create

// Create multiple public IP addresses if deployBastion is false
resource publicIpAddresses 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for i in range(1, numberOfIPAddresses): {
  name: '${publicIpAddressName}${i}'
  location: azureLocation
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}]

// Create multiple NIC IP configurations and assign the public IP to the IP configuration if deployBastion is false
resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: networkInterfaceName
  location: azureLocation
  properties: {
    ipConfigurations: [for i in range(1, numberOfIPAddresses): {
      name: 'ipconfig${i}'
      properties: {
        subnet: {
          id: subnetId
        }
        privateIPAllocationMethod: 'Dynamic'
        publicIPAddress: {
          id: publicIpAddresses[i-1].id
        }
        primary: i == 1 ? true : false
      }
    }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: azureLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: diskSize
      }
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: ubuntuOSVersion
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
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshRSAPublicKey
            }
          ]
        }
      }
    }
  }
}

// Add role assignment for the VM: Owner role
resource vmRoleAssignment_Owner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Microsoft.Authorization/roleAssignments', 'Owner')
  scope: resourceGroup()
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalType: 'ServicePrincipal'
  }
}

// Add role assignment for the VM: Storage Blob Data Contributor
resource vmRoleAssignment_Storage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Microsoft.Authorization/roleAssignments', 'Storage Blob Data Contributor')
  scope: resourceGroup()
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalType: 'ServicePrincipal'
  }
}

resource vmInstallscriptK3s 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'installscript_k3s'
  location: azureLocation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {}
    protectedSettings: {
      commandToExecute: 'bash installK3s.sh ${adminUsername} ${subscription().subscriptionId} ${vmName} ${azureLocation} ${stagingStorageAccountName} ${logAnalyticsWorkspace} ${templateBaseUrl} ${storageContainerName} ${k3sControlPlane}'
      fileUris: [
        '${templateBaseUrl}artifacts/installK3s.sh'
      ]
    }
  }
  dependsOn: [
    vmRoleAssignment_Owner
    vmRoleAssignment_Storage
  ]
}
