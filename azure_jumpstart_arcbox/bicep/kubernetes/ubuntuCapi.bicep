@description('Your public IP address, used to RDP to the client VM')
param myIpAddress string

@description('The name of you Virtual Machine')
param vmName string = 'ArcBox-CAPI-MGMT'

@description('The name of you Virtual Machine')
param capiArcDataClusterName string = 'ArcBox-CAPI-MGMT'

@description('Username for the Virtual Machine')
param adminUsername string = 'arcdemo'

@description('SSH Key for the Virtual Machine. SSH key is recommended over password')
@secure()
param sshRSAPublicKey string

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version')
@allowed([
  '20_04-lts-gen2'
])
param ubuntuOSVersion string = '20_04-lts-gen2'

@description('Location for all resources')
param azureLocation string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D4s_v4'

@description('Resource Id of the subnet in the virtual network')
param subnetId string

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'ArcBox-CAPI-MGMT-NSG'
param resourceTags object = {
  Project: 'jumpstart_arcbox'
}

@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Name for the staging storage account using to hold kubeconfig. This value is passed into the template as an output from mgmtStagingStorage.json')
param stagingStorageAccountName string

@description('Name of the Log Analytics workspace used with cluster extensions')
param logAnalyticsWorkspace string

@description('The base URL used for accessing artifacts and automation artifacts')
param artifactsBaseUrl string

var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: networkInterfaceName
  location: azureLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: networkSecurityGroupName
  location: azureLocation
  properties: {
    securityRules: [
      {
        name: 'allow_SSH'
        properties: {
          priority: 1001
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: myIpAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2021-03-01' = {
  name: publicIpAddressName
  location: azureLocation
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: azureLocation
  tags: resourceTags
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
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
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

resource vmInstallscriptCAPI 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: vm
  name: 'installscript_CAPI'
  location: azureLocation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {}
    protectedSettings: {
      commandToExecute: 'bash installCAPI.sh ${adminUsername} ${spnClientId} ${spnClientSecret} ${spnTenantId} ${vmName} ${resourceGroup().name} ${azureLocation} ${stagingStorageAccountName} ${logAnalyticsWorkspace} ${capiArcDataClusterName}'
      fileUris: [
        '${artifactsBaseUrl}artifacts/installCAPI.sh'
      ]
    }
  }
}
