@description('Your public IP address, used to RDP to the client VM')
param myIpAddress string

@description('The name of your Virtual Machine')
param vmName string = 'ArcBox-Client'

@description('The name of the Cluster API workload cluster to be connected as an Azure Arc-enabled Kubernetes cluster')
param capiArcDataClusterName string = 'ArcBox-CAPI-Data'

@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'arcdemo'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources')
param location string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D16s_v4'

@description('Resource Id of the subnet in the virtual network')
param subnetId string

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'ArcBox-NSG'
param resourceTags object = {
  Project: 'jumpstart_arcbox'
}

@description('Client id of the service principal')
param spnClientId string

@description('Client secret of the service principal')
@secure()
param spnClientSecret string
param spnAuthority string = environment().authentication.loginEndpoint

@description('Tenant id of the service principal')
param spnTenantId string
param azdataUsername string = 'arcdemo'

@secure()
param azdataPassword string = 'ArcPassword123!!'
param acceptEula string = 'yes'
param registryUsername string = 'registryUser'

@secure()
param registryPassword string = 'registrySecret'
param arcDcName string = 'arcdatactrl'
param mssqlmiName string = 'arcsqlmidemo'

@description('Name of PostgreSQL server group')
param postgresName string = 'arcpg'

@description('Number of PostgreSQL Hyperscale worker nodes')
param postgresWorkerNodeCount int = 3

@description('Size of data volumes in MB')
param postgresDatasize int = 1024

@description('Choose how PostgreSQL service is accessed through Kubernetes networking interface')
param postgresServiceType string = 'LoadBalancer'

@description('Name for the staging storage account using to hold kubeconfig. This value is passed into the template as an output from mgmtStagingStorage.json')
param stagingStorageAccountName string

@description('Name for the environment Azure Log Analytics workspace')
param workspaceName string

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'Full'
  'ITPro'
  'DevOps'
])
param flavor string = 'Full'

@description('Choice to deploy Bastion to connect to the client VM')
@allowed([
  'Yes'
  'No'
])
param deployBastion string = 'No'

var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var bastionSubnetIpPrefix = '172.16.3.0/27'
var PublicIPNoBastion = {
  id: '${publicIpAddress.id}'
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: PublicIPNoBastion
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
          sourceAddressPrefix: deployBastion == 'Yes' ? bastionSubnetIpPrefix : myIpAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2021-03-01' = if(deployBastion == 'No'){
  name: publicIpAddressName
  location: location
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
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 1024
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

resource vmBootstrap 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: vm
  name: 'Bootstrap'
  location: location
  tags: {
    displayName: 'config-choco'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -spnClientId ${spnClientId} -spnClientSecret ${spnClientSecret} -spnTenantId ${spnTenantId} -spnAuthority ${spnAuthority} -subscriptionId ${subscription().subscriptionId} -resourceGroup ${resourceGroup().name} -azdataUsername ${azdataUsername} -azdataPassword ${azdataPassword} -acceptEula ${acceptEula} -registryUsername ${registryUsername} -registryPassword ${registryPassword} -arcDcName ${arcDcName} -azureLocation ${location} -mssqlmiName ${mssqlmiName} -POSTGRES_NAME ${postgresName} -POSTGRES_WORKER_NODE_COUNT ${postgresWorkerNodeCount} -POSTGRES_DATASIZE ${postgresDatasize} -POSTGRES_SERVICE_TYPE ${postgresServiceType} -stagingStorageAccountName ${stagingStorageAccountName} -workspaceName ${workspaceName} -templateBaseUrl ${templateBaseUrl} -flavor ${flavor} -capiArcDataClusterName ${capiArcDataClusterName}'
    }
  }
}

output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion=='No' ? concat(publicIpAddress.properties.ipAddress) : ''
