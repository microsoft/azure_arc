@description('The name of your Virtual Machine')
param vmName string = '${namingPrefix}-Client'

@description('The name of the Cluster API workload cluster to be connected as an Azure Arc-enabled Kubernetes cluster')
param k3sArcDataClusterName string = '${namingPrefix}-K3s-Data'

@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'arcdemo'

@description('Enable automatic logon into ArcBox Virtual Machine')
param vmAutologon bool = false

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2025-datacenter-g2'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource Id of the subnet in the virtual network')
param subnetId string

param spnAuthority string = environment().authentication.loginEndpoint

@description('Your Microsoft Entra tenant Id')
param tenantId string
param azdataUsername string = 'arcdemo'

param acceptEula string = 'yes'
param registryUsername string = 'registryUser'

param arcDcName string = 'arcdatactrl'
param mssqlmiName string = 'arcsqlmidemo'

@description('Name of PostgreSQL server group')
param postgresName string = 'arcpg'

@description('Number of PostgreSQL worker nodes')
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

@description('Tags to assign for all ArcBox resources')
param resourceTags object = {
  Solution: 'jumpstart_arcbox'
}

@maxLength(7)
@description('The naming prefix for the nested virtual machines. Example: ArcBox-Win2k19')
param namingPrefix string = 'ArcBox'

@description('The flavor of ArcBox you want to deploy. Valid values are: \'ITPro\', \'DevOps\', \'DataOps\'')
@allowed([
  'ITPro'
  'DevOps'
  'DataOps'
])
param flavor string = 'ITPro'

@description('SQL Server edition to deploy. Valid values are: \'Developer\', \'Standard\', \'Enterprise\'')
@allowed([
  'Developer'
  'Standard'
  'Enterprise'
])
param sqlServerEdition string = 'Developer'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked https://github.com/Azure/jumpstart-apps')
param githubUser string

@description('Git branch to use from the forked repo https://github.com/Azure/jumpstart-apps')
param githubBranch string

@description('The name of the K3s cluster')
param k3sArcClusterName string = '${namingPrefix}-K3s'

@description('The name of the AKS cluster')
param aksArcClusterName string = '${namingPrefix}-AKS-Data'

@description('The name of the AKS DR cluster')
param aksdrArcClusterName string = '${namingPrefix}-AKS-DR-Data'

@description('Domain name for the jumpstart environment')
param addsDomainName string = 'jumpstart.local'

@description('The custom location RPO ID. This parameter is only needed when deploying the DataOps flavor.')
param customLocationRPOID string = ''

@description('The SKU of the VMs disk')
param vmsDiskSku string = 'PremiumV2_LRS'

@description('Use this parameter to enable or disable debug mode for the automation scripts on the client VM, effectively configuring PowerShell ErrorActionPreference to Break. Default is false.')
param debugEnabled bool = false

param autoShutdownEnabled bool = true
param autoShutdownTime string = '1800' // The time for auto-shutdown in HHmm format (24-hour clock)
param autoShutdownTimezone string = 'UTC' // Timezone for the auto-shutdown
param autoShutdownEmailRecipient string = ''

@description('The availability zone for the Virtual Machine, public IP, and data disk for the ArcBox client VM')
@allowed([
  '1'
  '2'
  '3'
])
param zones string = '1'

@description('Option to enable spot pricing for the ArcBox Client VM')
param enableAzureSpotPricing bool = false

var bastionName = '${namingPrefix}-Bastion'
var publicIpAddressName = deployBastion == false ? '${vmName}-PIP' : '${bastionName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}
resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
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
          publicIPAddress: deployBastion == false ? PublicIPNoBastion : null
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastion == false) {
  name: publicIpAddressName
  location: location
  zones: [zones]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource vmDisk 'Microsoft.Compute/disks@2024-03-02' = {
  location: location
  name: '${vmName}-VMsDisk'
  zones: [zones]
  sku: {
    name: vmsDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 256
    burstingEnabled: false
    diskMBpsReadWrite: 200
    diskIOPSReadWrite: 5000
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  zones: [zones]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: flavor == 'DevOps' ? 'Standard_B4ms' : flavor == 'DataOps' ? 'Standard_D8s_v5' : 'Standard_D8s_v5'
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 127
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      dataDisks: [
        {
          createOption: 'Attach'
          lun: 0
          managedDisk: {
            id: vmDisk.id
          }
        }
      ]
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
        enableAutomaticUpdates: true
      }
    }
    priority: enableAzureSpotPricing ? 'Spot' : 'Regular'
    evictionPolicy: enableAzureSpotPricing ? 'Deallocate' : null
    billingProfile: enableAzureSpotPricing ? {
      maxPrice: -1
    } : null
  }
}

resource vmBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'Bootstrap'
  location: location
  tags: {
    displayName: 'config-bootstrap'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -tenantId ${tenantId} -spnAuthority ${spnAuthority} -subscriptionId ${subscription().subscriptionId} -resourceGroup ${resourceGroup().name} -azdataUsername ${azdataUsername} -acceptEula ${acceptEula} -registryUsername ${registryUsername} -arcDcName ${arcDcName} -azureLocation ${location} -mssqlmiName ${mssqlmiName} -POSTGRES_NAME ${postgresName} -POSTGRES_WORKER_NODE_COUNT ${postgresWorkerNodeCount} -POSTGRES_DATASIZE ${postgresDatasize} -POSTGRES_SERVICE_TYPE ${postgresServiceType} -stagingStorageAccountName ${stagingStorageAccountName} -workspaceName ${workspaceName} -templateBaseUrl ${templateBaseUrl} -flavor ${flavor} -k3sArcDataClusterName ${k3sArcDataClusterName} -k3sArcClusterName ${k3sArcClusterName} -aksArcClusterName ${aksArcClusterName} -aksdrArcClusterName ${aksdrArcClusterName} -githubUser ${githubUser} -githubBranch ${githubBranch} -vmAutologon ${vmAutologon} -rdpPort ${rdpPort} -addsDomainName ${addsDomainName} -customLocationRPOID ${customLocationRPOID} -resourceTags ${resourceTags} -namingPrefix ${namingPrefix} -debugEnabled ${debugEnabled} -sqlServerEdition ${sqlServerEdition} -autoShutdownEnabled ${autoShutdownEnabled}'
    }
  }
}

// Add role assignment for the VM: Azure Key Vault Administrator role
resource vmRoleAssignment_KeyVaultAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Microsoft.Authorization/roleAssignments', 'Administrator')
  scope: resourceGroup()
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
    principalType: 'ServicePrincipal'

  }
}

// Add role assignment for the deploy user: Azure Key Vault Administrator role
resource deployerRoleAssignment_KeyVaultAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id,deployer().objectId, resourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483'))
  scope: resourceGroup()
  properties: {
    principalId: deployer().objectId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
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

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = if (autoShutdownEnabled) {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimezone
    notificationSettings: {
      status: empty(autoShutdownEmailRecipient) ? 'Disabled' : 'Enabled' // Set status based on whether an email is provided
      timeInMinutes: 30
      webhookUrl: ''
      emailRecipient: autoShutdownEmailRecipient
      notificationLocale: 'en'
    }
    targetResourceId: vm.id
  }
}

output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion == false ? concat(publicIpAddress.properties.ipAddress) : ''
