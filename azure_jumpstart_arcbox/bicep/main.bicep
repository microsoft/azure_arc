@description('RSA public key used for securing SSH access to ArcBox resources')
@secure()
param sshRSAPublicKey string

@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Enable automatic logon into ArcBox Virtual Machine')
param vmAutologon bool = false

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
param githubBranch string = 'arcbox_3.0'

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

@description('The custom location RPO ID')
param customLocationRPOID string

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_arcbox/'
var aksArcDataClusterName = 'ArcBox-AKS-Data-${guid}'
var aksDrArcDataClusterName = 'ArcBox-AKS-DR-Data-${guid}'
var k3sArcDataClusterName = 'ArcBox-DataSvc-K3s-${guid}'
var k3sArcClusterName = 'ArcBox-K3s-${guid}'
var k3sClusterNodesCount = 3 // Number of nodes to deploy in the K3s cluster

module ubuntuRancherK3sDataSvcDeployment 'kubernetes/ubuntuRancher.bicep' = if (flavor == 'DevOps' || flavor == 'DataOps') {
  name: 'ubuntuRancherK3sDataSvcDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    deployBastion: deployBastion
    azureLocation: location
    vmName : k3sArcDataClusterName
    storageContainerName: toLower(k3sArcDataClusterName)
    flavor: flavor
  }
}

module ubuntuRancherK3sDataSvcNodesDeployment 'kubernetes/ubuntuRancherNodes.bicep' = [for i in range(0, k3sClusterNodesCount): if (flavor == 'Full' || flavor == 'DataOps') {
  name: 'ubuntuRancherK3sDataSvcNodesDeployment-${i}'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    azureLocation: location
    flavor: flavor
    vmName : '${k3sArcDataClusterName}-Node-0${i}'
    storageContainerName: toLower(k3sArcDataClusterName)
  }
  dependsOn: [
    ubuntuRancherK3sDataSvcDeployment
  ]
}]

module ubuntuRancherK3sDeployment 'kubernetes/ubuntuRancher.bicep' = if (flavor == 'DevOps') {
  name: 'ubuntuRancherK3sDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    deployBastion: deployBastion
    azureLocation: location
    vmName : k3sArcClusterName
    storageContainerName: toLower(k3sArcClusterName)
    flavor: flavor
  }
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    azdataPassword: windowsAdminPassword
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    flavor: flavor
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    deployBastion: deployBastion
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
  }
  dependsOn: [
    updateVNetDNSServers
  ]
}

module stagingStorageAccountDeployment 'mgmt/mgmtStagingStorage.bicep' = {
  name: 'stagingStorageAccountDeployment'
  params: {
    location: location
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
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    location: location
    aksClusterName : aksArcDataClusterName
    drClusterName : aksDrArcDataClusterName
  }
  dependsOn: [
    updateVNetDNSServers
    stagingStorageAccountDeployment
    mgmtArtifactsAndPolicyDeployment
  ]
}

output clientVmLogonUserName string = flavor == 'DataOps' ? '${windowsAdminUsername}@${addsDomainName}' : ''
