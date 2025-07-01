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

@description('Tenant id of the service principal')
param tenantId string

@description('Name for the environment Azure Log Analytics workspace')
param workspaceName string

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Storage account used for staging file artifacts')
param storageAccountName string

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Random GUID')
param namingGuid string

@description('The custom location RPO ID')
param customLocationRPOID string

@description('The agora scenario to be deployed')
param scenario string = 'contoso_supermarket'

@description('The name of the Azure Arc K3s cluster')
param k3sArcDataClusterName string = 'Ag-K3s-Seattle-${namingGuid}'

@description('The name of the Azure Arc K3s data cluster')
param k3sArcClusterName string = 'Ag-K3s-Chicago-${namingGuid}'

@description('The URL of the Azure OpenAI endpoint.')
param openAIEndpoint string

@description('The URL of the Speech-to-text endpoint.')
param speachToTextEndpoint string

@description('The array of OpenAI models to deploy')
param azureOpenAIModel object = {
  name: 'gpt-4o'
  version: '2024-05-13'
  apiVersion: '2024-08-01-preview'
}

@description('The name of the OpenAI deployment name.')
param openAIDeploymentName string = ''

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
    name: 'Standard'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: resourceTags
  identity: {
    type: 'SystemAssigned'
  }
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
      dataDisks: []
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -adminPassword ${encodedPassword} -tenantId ${tenantId} -subscriptionId ${subscription().subscriptionId} -resourceGroup ${resourceGroup().name} -azureLocation ${location} -stagingStorageAccountName ${storageAccountName} -workspaceName ${workspaceName} -templateBaseUrl ${templateBaseUrl} -rdpPort ${rdpPort} -githubAccount ${githubAccount} -githubBranch ${githubBranch} -namingGuid ${namingGuid} -customLocationRPOID ${customLocationRPOID} -scenario ${scenario} -aioStorageAccountName ${aioStorageAccountName} -k3sArcClusterName ${k3sArcClusterName} -k3sArcDataClusterName ${k3sArcDataClusterName} -openAIEndpoint ${openAIEndpoint} -speachToTextEndpoint ${speachToTextEndpoint} -vmAutologon ${vmAutologon} -azureOpenAIModel ${azureOpenAIModel} -openAIDeploymentName ${openAIDeploymentName}'
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

// Add role assignment for the VM: Cognitive Services OpenAI Contributor
resource vmRoleAssignment_OpenAI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vm.id, 'Microsoft.Authorization/roleAssignments', 'Cognitive Services OpenAI Contributor')
  scope: resourceGroup()
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
    principalType: 'ServicePrincipal'
  }
}

output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion == false ? concat(publicIpAddress.properties.ipAddress) : ''
