@description('The name of you Virtual Machine')
param vmName string = 'ArcBox-K3s'

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

@description('Location for all resources.')
param azureLocation string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_B4ms'

@description('Resource Id of the subnet in the virtual network')
param subnetId string

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
param templateBaseUrl string

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}


resource networkInterface 'Microsoft.Network/networkInterfaces@2022-01-01' = {
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
          publicIPAddress: deployBastion== false  ? PublicIPNoBastion : json('null')
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2022-01-01' = if(deployBastion == false){
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

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
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

resource vmInstallscriptK3s 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
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
      commandToExecute: 'bash installK3s.sh ${adminUsername} ${spnClientId} ${spnClientSecret} ${spnTenantId} ${vmName} ${azureLocation} ${stagingStorageAccountName} ${logAnalyticsWorkspace} ${deployBastion}'
      fileUris: [
        '${templateBaseUrl}artifacts/installK3s.sh'
      ]
    }
  }
}
