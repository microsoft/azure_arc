@description('RSA public key used for securing SSH access to ArcBox resources. This parameter is only needed when deploying the DataOps or DevOps flavors.')
@secure()
param sshRSAPublicKey string = ''

@description('Your Microsoft Entra tenant Id')
param tenantId string = tenant().tenantId

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Enable automatic logon into ArcBox Virtual Machine')
param vmAutologon bool = true

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\', \'DataOps\'')
@allowed([
  'ITPro'
  'DevOps'
  'DataOps'
])
param flavor string = 'ITPro'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Bastion host Sku name. The Developer SKU is currently supported in a limited number of regions: https://learn.microsoft.com/azure/bastion/quickstart-developer-sku')
@allowed([
  'Basic'
  'Standard'
  'Developer'
])
param bastionSku string = 'Basic'

@description('User github account where they have forked https://github.com/microsoft/azure-arc-jumpstart-apps')
param githubUser string = 'microsoft'

@description('Active directory domain services domain name')
param addsDomainName string = 'jumpstart.local'

@description('Random GUID for cluster names')
param guid string = substring(newGuid(),0,4)

@description('Azure location to deploy all resources')
param location string = resourceGroup().location

@description('The custom location RPO ID. This parameter is only needed when deploying the DataOps flavor.')
param customLocationRPOID string = newGuid()

@description('Use this parameter to enable or disable debug mode for the automation scripts on the client VM, effectively configuring PowerShell ErrorActionPreference to Break. Intended for use when troubleshooting automation scripts. Default is false.')
param debugEnabled bool = false

@description('Tags to assign for all ArcBox resources')
param resourceTags object = {
  Solution: 'jumpstart_arcbox'
}

@maxLength(7)
@description('The naming prefix for the nested virtual machines and all Azure resources deployed. The maximum length for the naming prefix is 7 characters,example: `ArcBox-Win2k19`')
param namingPrefix string = 'ArcBox'

param autoShutdownEnabled bool = false
param autoShutdownTime string = '1800' // The time for auto-shutdown in HHmm format (24-hour clock)
param autoShutdownTimezone string = 'UTC' // Timezone for the auto-shutdown
param autoShutdownEmailRecipient string = ''

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_arcbox/'
var aksArcDataClusterName = '${namingPrefix}-AKS-Data-${guid}'
var aksDrArcDataClusterName = '${namingPrefix}-AKS-DR-Data-${guid}'
var k3sArcDataClusterName = '${namingPrefix}-K3s-Data-${guid}'
var k3sArcClusterName = '${namingPrefix}-K3s-${guid}'
var k3sClusterNodesCount = 3 // Number of nodes to deploy in the K3s cluster

module ubuntuRancherK3sDataSvcDeployment 'kubernetes/ubuntuRancher.bicep' = if (flavor == 'DevOps' || flavor == 'DataOps') {
  name: 'ubuntuRancherK3sDataSvcDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(stagingStorageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    azureLocation: location
    vmName : k3sArcDataClusterName
    storageContainerName: toLower(k3sArcDataClusterName)
    flavor: flavor
    namingPrefix: namingPrefix
  }
}

module ubuntuRancherK3sDataSvcNodesDeployment 'kubernetes/ubuntuRancherNodes.bicep' = [for i in range(0, k3sClusterNodesCount): if (flavor == 'DataOps' || flavor == 'DevOps') {
  name: 'ubuntuRancherK3sDataSvcNodesDeployment-${i}'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(stagingStorageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    azureLocation: location
    flavor: flavor
    vmName : '${k3sArcDataClusterName}-Node-0${i}'
    storageContainerName: toLower(k3sArcDataClusterName)
    namingPrefix: namingPrefix
  }
  dependsOn: [
    ubuntuRancherK3sDataSvcDeployment
  ]
}]

module ubuntuRancherK3sDeployment 'kubernetes/ubuntuRancher.bicep' = if (flavor == 'DevOps') {
  name: 'ubuntuRancherK3sDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(stagingStorageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    azureLocation: location
    vmName : k3sArcClusterName
    storageContainerName: toLower(k3sArcClusterName)
    flavor: flavor
    namingPrefix: namingPrefix
  }
}

module ubuntuRancherK3sNodesDeployment 'kubernetes/ubuntuRancherNodes.bicep' = [for i in range(0, k3sClusterNodesCount): if (flavor == 'DevOps') {
  name: 'ubuntuRancherK3sNodesDeployment-${i}'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    stagingStorageAccountName: toLower(stagingStorageAccountDeployment.outputs.storageAccountName)
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    azureLocation: location
    flavor: flavor
    vmName : '${k3sArcClusterName}-Node-0${i}'
    storageContainerName: toLower(k3sArcClusterName)
    namingPrefix: namingPrefix
  }
  dependsOn: [
    ubuntuRancherK3sDeployment
  ]
}]

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    azdataPassword: windowsAdminPassword
    tenantId: tenantId
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: toLower(stagingStorageAccountDeployment.outputs.storageAccountName)
    templateBaseUrl: templateBaseUrl
    flavor: flavor
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    deployBastion: deployBastion
    githubBranch: githubBranch
    githubUser: githubUser
    location: location
    k3sArcDataClusterName : k3sArcDataClusterName
    k3sArcClusterName : k3sArcClusterName
    aksArcClusterName : aksArcDataClusterName
    aksdrArcClusterName : aksDrArcDataClusterName
    vmAutologon: vmAutologon
    rdpPort: rdpPort
    addsDomainName: addsDomainName
    customLocationRPOID: customLocationRPOID
    namingPrefix: namingPrefix
    debugEnabled: debugEnabled
    autoShutdownEnabled: autoShutdownEnabled
    autoShutdownTime: autoShutdownTime
    autoShutdownTimezone: autoShutdownTimezone
    autoShutdownEmailRecipient: empty(autoShutdownEmailRecipient) ? null : autoShutdownEmailRecipient
  }
  dependsOn: [
    updateVNetDNSServers
    ubuntuRancherK3sDataSvcDeployment
    ubuntuRancherK3sDeployment
  ]
}

module stagingStorageAccountDeployment 'mgmt/mgmtStagingStorage.bicep' = {
  name: 'stagingStorageAccountDeployment'
  params: {
    location: location
    namingPrefix: namingPrefix
  }
}

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    flavor: flavor
    deployBastion: deployBastion
    bastionSku: bastionSku
    location: location
    resourceTags: resourceTags
    namingPrefix: namingPrefix
  }
}

module addsVmDeployment 'mgmt/addsVm.bicep' = if (flavor == 'DataOps'){
  name: 'addsVmDeployment'
  params: {
    windowsAdminUsername : windowsAdminUsername
    windowsAdminPassword : windowsAdminPassword
    addsDomainName: addsDomainName
    deployBastion: deployBastion
    templateBaseUrl: templateBaseUrl
    azureLocation: location
    namingPrefix: namingPrefix
  }
  dependsOn:[
    mgmtArtifactsAndPolicyDeployment
  ]
}

module updateVNetDNSServers 'mgmt/mgmtArtifacts.bicep' = if (flavor == 'DataOps'){
  name: 'updateVNetDNSServers'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    flavor: flavor
    deployBastion: deployBastion
    location: location
    dnsServers: [
    '10.16.2.100'
    '168.63.129.16'
    ]
    namingPrefix: namingPrefix
  }
  dependsOn: [
    addsVmDeployment
    mgmtArtifactsAndPolicyDeployment
  ]
}

module aksDeployment 'kubernetes/aks.bicep' = if (flavor == 'DataOps') {
  name: 'aksDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    location: location
    aksClusterName : aksArcDataClusterName
    drClusterName : aksDrArcDataClusterName
    namingPrefix: namingPrefix
  }
  dependsOn: [
    updateVNetDNSServers
    stagingStorageAccountDeployment
    mgmtArtifactsAndPolicyDeployment
  ]
}

output clientVmLogonUserName string = flavor == 'DataOps' ? '${windowsAdminUsername}@${addsDomainName}' : ''
