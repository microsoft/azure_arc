@description('IP address allowed SSH and RDP access to ArcBox resources. Usually this is your home or office public IP address')
param myIpAddress string

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

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\', \'DevOps\'')
@allowed([
  'Full'
  'ITPro'
  'DevOps'
])
param flavor string = 'Full'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_arcbox/'

module ubuntuCAPIDeployment 'kubernetes/ubuntuCapi.bicep' = if (flavor == 'Full') {
  name: 'ubuntuCAPIDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    myIpAddress: myIpAddress
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
  }
}

module ubuntuRancherDeployment 'kubernetes/ubuntuRancher.bicep' = if (flavor == 'Full') {
  name: 'ubuntuRancherDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    myIpAddress: myIpAddress
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    logAnalyticsWorkspace: logAnalyticsWorkspaceName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
  }
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    myIpAddress: myIpAddress
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    flavor: flavor
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
  }
}

module stagingStorageAccountDeployment 'mgmt/mgmtStagingStorage.bicep' = {
  name: 'stagingStorageAccountDeployment'
  params: {}
}

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    flavor: flavor
  }
}
