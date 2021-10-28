@description('IP address allowed SSH and RDP access to ArcBox resources. Usually this is your home or office public IP address.')
param myIpAddress string

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
param windowsAdminPassword string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string

var templateBaseUrl = 'https://raw.githubusercontent.com/dkirby-ms/azure_arc/main/azure_jumpstart_arcbox/'
var clientVmTemplateUrl = uri(templateBaseUrl, 'clientVm/clientVm.json')
var mgmtTemplateUrl = uri(templateBaseUrl, 'mgmt/mgmtArtifacts.json')
var mgmtStagingStorageUrl = uri(templateBaseUrl, 'mgmt/mgmtStagingStorage.json')

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
    templateBaseUrl: templateBaseUrl
  }
}
