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

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'arc_servers_level_up'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked https://github.com/microsoft/azure-arc-jumpstart-apps')
param githubUser string = 'sebassem'

@description('Override default RDP port 3389 using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Override default SSH port 22 using this parameter. Default is 22. No changes will be made to the client VM.')
param sshPort string = '22'

@description('Your email address to configure alerts.')
param emailAddress string

param location string = resourceGroup().location

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_arcbox_servers_levelup/'

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    workspaceName: logAnalyticsWorkspaceName
    stagingStorageAccountName: stagingStorageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    subnetId: mgmtArtifactsAndPolicyDeployment.outputs.subnetId
    deployBastion: deployBastion
    githubUser: githubUser
    location: location
    rdpPort: rdpPort
    sshPort: sshPort
  }
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
    deployBastion: deployBastion
    location: location
  }
}

module monitoringResources 'mgmt/monitoringResources.bicep' = {
  name: 'monitoringResources'
  params: {
    workspaceId: mgmtArtifactsAndPolicyDeployment.outputs.workspaceId
    workspaceName: logAnalyticsWorkspaceName
    location: location
    emailAddress: emailAddress
  }
}

module policyDeployment 'mgmt/policyAzureArc.bicep' = {
  name: 'policyDeployment'
  dependsOn: [
    mgmtArtifactsAndPolicyDeployment
  ]
  params: {
    azureLocation: location
    changeTrackingDCR: dataCollectionRules.outputs.changeTrackingDCR
    //logAnalyticsWorkspaceId: workspace.id
  }
}

module dataCollectionRules 'mgmt/mgmtDataCollectionRules.bicep' = {
  name: 'dataCollectionRules'
  params: {
    workspaceLocation: location
    workspaceName: logAnalyticsWorkspaceName
    workspaceResourceId: mgmtArtifactsAndPolicyDeployment.outputs.workspaceId
  }
}
