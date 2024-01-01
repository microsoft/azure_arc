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
  'Full'
  'ITPro'
  'DevOps'
  'DataOps'
])
param flavor string = 'Full'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked https://github.com/microsoft/azure-arc-jumpstart-apps')
param githubUser string = 'microsoft'

@description('Active directory domain services domain name')
param addsDomainName string = 'jumpstart.local'

@description('Random GUID for cluster names')
param guid string = substring(newGuid(),0,4)

@description('Azure location to deploy all resources')
param location string = resourceGroup().location

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_arcbox/'

var capiArcDataClusterName = 'ArcBox-CAPI-Data-${guid}'
var k3sArcDataClusterName = 'ArcBox-K3s-${guid}'
var aksArcDataClusterName = 'ArcBox-AKS-Data-${guid}'
var aksDrArcDataClusterName = 'ArcBox-AKS-DR-Data-${guid}'

module ubuntuCAPIDeployment 'kubernetes/ubuntuCapi.bicep' = if (flavor == 'Full' || flavor == 'DevOps' || flavor == 'DataOps') {
  name: 'ubuntuCAPIDeployment'
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
    flavor: flavor
    capiArcDataClusterName : capiArcDataClusterName
  }
  dependsOn: [
    updateVNetDNSServers
  ]
}

module ubuntuRancherDeployment 'kubernetes/ubuntuRancher.bicep' = if (flavor == 'Full' || flavor == 'DevOps') {
  name: 'ubuntuRancherDeployment'
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
    k3sArcClusterName : k3sArcDataClusterName
    capiArcDataClusterName : capiArcDataClusterName
    aksArcClusterName : aksArcDataClusterName
    aksdrArcClusterName : aksDrArcDataClusterName
    vmAutologon: vmAutologon
    rdpPort: rdpPort
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
