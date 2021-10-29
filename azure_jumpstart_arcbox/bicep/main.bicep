@description('IP address allowed SSH and RDP access to ArcBox resources. Usually this is your home or office public IP address.')
param myIpAddress string

@description('RSA public key used for securing SSH access to ArcBox resources.')
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

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.')
@minLength(12)
@maxLength(123)
@secure()
param password string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'Full'
  'ITPro'
])
param flavor string = 'Full'

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
param artifactsBaseUrl string = 'https://raw.githubusercontent.com/microsoft/azure_arc/azure_jumpstart_arcbox/'

module ubuntuCAPIDeployment 'kubernetes/ubuntuCapi.bicep' = if (flavor == 'Full') {
  name: 'ubuntuCAPIDeployment'
  params: {
    sshRSAPublicKey: sshRSAPublicKey
    myIpAddress: myIpAddress
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    artifactsBaseUrl: artifactsBaseUrl
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
    artifactsBaseUrl: artifactsBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
  }
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: password
    azdataPassword: password
    registryPassword: password
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    myIpAddress: myIpAddress
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    artifactsBaseUrl: artifactsBaseUrl
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
  }
}
