@description('The name of your Virtual Machine')
param vmName string = 'Ag-VM-Client'

@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'agora'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Enable automatic logon into Virtual Machine')
param vmAutologon bool = false

@description('Name of the storage account')
param aioStorageAccountName string = 'aiostg${namingGuid}'

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('Resource Id of the subnet in the virtual network')
param subnetId string

@description('Client id of the service principal')
param spnClientId string

@description('Azure service principal object id')
param spnObjectId string

@description('Client secret of the service principal')
@secure()
param spnClientSecret string
param spnAuthority string = environment().authentication.loginEndpoint

@description('Tenant id of the service principal')
param spnTenantId string

@description('Name for the environment Azure Log Analytics workspace')
param workspaceName string

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Storage account used for staging file artifacts')
param storageAccountName string

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

//@description('GitHub Personal access token for the user account')
//@secure()
//param githubPAT string

@description('Random GUID')
param namingGuid string

@description('The custom location RPO ID')
param customLocationRPOID string

@description('The agora scenario to be deployed')
param scenario string = 'contoso_motors'

var encodedPassword = base64(windowsAdminPassword)
var bastionName = 'Ag-Bastion'
var publicIpAddressName = deployBastion == false ? '${vmName}-PIP' : '${bastionName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-02-01' = {
  name: networkInterfaceName
  location: location
  tags: resourceTags
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

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2023-02-01' = if (deployBastion == false) {
  name: publicIpAddressName
  location: location
  tags: resourceTags
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D8s_v5'
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 256
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      dataDisks: [
        {
          diskSizeGB: 1024
          lun: 0
          createOption: 'Empty'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
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
        enableVMAgentPlatformUpdates: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'Never'
          }
        }
      }
    }
  }
}

resource vmBootstrap 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
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
    protectedSettings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/PowerShell/Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -adminPassword ${encodedPassword} -spnClientId ${spnClientId} -spnClientSecret ${spnClientSecret} -spnObjectId ${spnObjectId} -spnTenantId ${spnTenantId} -spnAuthority ${spnAuthority} -subscriptionId ${subscription().subscriptionId} -resourceGroup ${resourceGroup().name} -azureLocation ${location} -stagingStorageAccountName ${storageAccountName} -workspaceName ${workspaceName} -templateBaseUrl ${templateBaseUrl} -rdpPort ${rdpPort} -githubAccount ${githubAccount} -githubBranch ${githubBranch} -namingGuid ${namingGuid} -adxClusterName ${adxClusterName} -customLocationRPOID ${customLocationRPOID} -scenario ${scenario} -aioStorageAccountName ${aioStorageAccountName} -vmAutologon ${vmAutologon}'
    }
  }
}

// Add role assignment for the VM: Azure Key Vault Secret Officer role
resource vmRoleAssignment_KeyVaultAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Microsoft.Authorization/roleAssignments', 'Administrator')
  scope: resourceGroup()
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
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

// Add role assignment for the VM: Owner
resource vmRoleAssignment_Owner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Microsoft.Authorization/roleAssignments', 'Owner')
  scope: resourceGroup()
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalType: 'ServicePrincipal'
  }
}


output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion == false ? concat(publicIpAddress.properties.ipAddress) : ''
