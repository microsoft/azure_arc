@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string = 'AKS-EE-Full-Vnet'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloud string = 'AKS-EE-Full-Subnet'

@allowed([
  'k8s'
  'k3s'
])
@description('AKS Edge Essentials Kubernetes distribution')
param kubernetesDistribution string

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_arc_k8s_jumpstart/aks_hybrid/aks_edge_essentials_full_akri/bicep_template/'

module networkDeployment 'mgmt/network.bicep' = {
  name: 'networkDeployment'
  params: {
    virtualNetworkNameCloud : virtualNetworkNameCloud
    subnetNameCloud : subnetNameCloud
    deployBastion: deployBastion
    location: location
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
    templateBaseUrl: templateBaseUrl
    deployBastion: deployBastion
    githubAccount: githubAccount
    githubBranch: githubBranch
    location: location
    subnetId: networkDeployment.outputs.subnetId
    kubernetesDistribution: kubernetesDistribution
  }
}
