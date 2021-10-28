@description('Your public IP address, used to RDP to the client VM')
param myIpAddress string

@description('The name of you Virtual Machine.')
param vmName string = 'ArcBox-K3s'

@description('Username for the Virtual Machine.')
param adminUsername string = 'arcdemo'

@description('SSH Key for the Virtual Machine. SSH key is recommended over password.')
@secure()
param sshRSAPublicKey string

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
@allowed([
  '18.04-LTS'
])
param ubuntuOSVersion string = '18.04-LTS'

@description('Location for all resources.')
param azureLocation string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D4s_v3'

@description('Name of the VNet')
param virtualNetworkName string = 'ArcBox-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'ArcBox-Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'ArcBox-K3s-NSG'
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

@description('Name of the Log Analytics workspace used with Azure Monitor for Containers extension.')
param logAnalyticsWorkspace string

@description('The base URL used for accessing templates and automation artifacts. Typically inherited from parent ARM template.')
param templateBaseUrl string

var vmName_var = concat(vmName)
var publicIpAddressName_var = '${vmName}-PIP'
var networkInterfaceName_var = '${vmName}-NIC'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var osDiskType = 'Premium_LRS'

resource networkInterfaceName 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: networkInterfaceName_var
  location: azureLocation
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
}

resource networkSecurityGroupName_resource 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
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
      {
        name: 'allow_k8s_6443'
        properties: {
          priority: 1002
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '6443'
        }
      }
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
    ]
  }
}

resource publicIpAddressName 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpAddressName_var
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

resource vmName_resource 'Microsoft.Compute/virtualMachines@2019-03-01' = {
  name: vmName_var
  location: azureLocation
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
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: ubuntuOSVersion
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

resource vmName_installscript_k3s 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vmName_resource
  name: 'installscript_k3s'
  location: azureLocation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {}
    protectedSettings: {
      commandToExecute: 'bash installK3s.sh ${adminUsername} ${spnClientId} ${spnClientSecret} ${spnTenantId} ${vmName} ${azureLocation} ${stagingStorageAccountName} ${logAnalyticsWorkspace}'
      fileUris: [
        '${templateBaseUrl}artifacts/installK3s.sh'
      ]
    }
  }
}
