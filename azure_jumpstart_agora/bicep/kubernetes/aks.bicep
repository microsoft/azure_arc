@description('The name of the Prod Kubernetes cluster resource')
param aksProdClusterName string

@description('The name of the Dev Kubernetes cluster resource')
param aksDevClusterName string

@description('The location of the Managed Cluster resource')
param location string = resourceGroup().location

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN prod')
param dnsPrefixProd string = 'agora-prod'

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN dev')
param dnsPrefixDev string = 'agora-dev'

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@description('The number of nodes for the cluster')
@minValue(1)
@maxValue(50)
param agentCount int = 2

@description('The size of the Virtual Machine')
param agentVMSize string = 'Standard_D2s_v4'

@description('User name for the Linux Virtual Machines')
param linuxAdminUsername string = 'arcdemo'

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string

@description('Client ID (used by cloudprovider)')
@secure()
param spnClientId string

@description('The Service Principal Client Secret')
@secure()
param spnClientSecret string

@description('boolean flag to turn on and off of RBAC')
param enableRBAC bool = true

@description('The name of the cloud virtual network')
param virtualNetworkNameCloud string

@description('The name of the cloud aks subnet')
param aksSubnetNameProd string

@description('The name of the dev aks subnet')
param aksSubnetNameDev string
//param aksSubnetNameInnerLoop string = 'Agora-Cloud-Inner-Loop-Subnet'

@minLength(5)
@maxLength(50)
@description('Name of the production Azure Container Registry')
param acrNameProd string

@minLength(5)
@maxLength(50)
@description('Name of the dev Azure Container Registry')
param acrNameDev string

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

@description('The type of operating system')
@allowed([
  'Linux'
])
param osType string = 'Linux'
var tier  = 'free'

@description('The version of Kubernetes')
param kubernetesVersion string = '1.24.6'

var serviceCidr_prod = '10.20.64.0/19'
var dnsServiceIP_prod = '10.20.64.10'
var dockerBridgeCidr_prod = '172.17.0.1/16'

var serviceCidr_dev = '10.21.64.0/19'
var dnsServiceIP_dev = '10.21.64.10'
var dockerBridgeCidr_dev = '172.18.0.1/16'

@description('The role Id of ACR pull role')
var acrPullRoleID = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

@description('The role Id of ACR push role')
var acrPushRoleID = '8311e382-0749-4cb8-b61a-304f252e45ec'

resource aksProd 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  location: location
  name: aksProdClusterName
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: tier
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    dnsPrefix: dnsPrefixProd
    aadProfile: {
      managed: true
    }
    agentPoolProfiles: [
      {
        name: 'agentpool'
        mode: 'System'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: osType
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkNameCloud, aksSubnetNameProd)
      }
    ]
    storageProfile:{
      diskCSIDriver: {
        enabled: true
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: serviceCidr_prod
      dnsServiceIP: dnsServiceIP_prod
      dockerBridgeCidr: dockerBridgeCidr_prod
    }
    linuxProfile: {
      adminUsername: linuxAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshRSAPublicKey
          }
        ]
      }
    }
    servicePrincipalProfile: {
      clientId: spnClientId
      secret: spnClientSecret
    }
  }
}

resource aksDev 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  location: location
  name: aksDevClusterName
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: tier
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    dnsPrefix: dnsPrefixDev
    aadProfile: {
      managed: true
    }
    agentPoolProfiles: [
      {
        name: 'agentpool'
        mode: 'System'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: osType
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkNameCloud, aksSubnetNameDev)
      }
    ]
    storageProfile:{
      diskCSIDriver: {
        enabled: true
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: serviceCidr_dev
      dnsServiceIP: dnsServiceIP_dev
      dockerBridgeCidr: dockerBridgeCidr_dev
    }
    linuxProfile: {
      adminUsername: linuxAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshRSAPublicKey
          }
        ]
      }
    }
    servicePrincipalProfile: {
      clientId: spnClientId
      secret: spnClientSecret
    }
  }
}

resource acrResourceProd 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrNameProd
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource acrResourceDev 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrNameDev
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource pullRoleassignmentProd 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResourceProd
  name: guid(aksProd.id, acrPullRoleID)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleID)
    principalId: aksProd.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource pullRoleassignmentDev 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResourceDev
  name: guid(aksDev.id, acrPullRoleID)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleID)
    principalId: aksDev.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource pushRoleassignmentProd 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResourceProd
  name: guid(aksProd.id, acrPushRoleID)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleID)
    principalId: aksProd.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource pushRoleassignmentDev 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acrResourceDev
  name: guid(aksDev.id, acrPushRoleID)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleID)
    principalId: aksDev.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Output the login server property for Dev ACR')
output acrDevLoginServer string = acrResourceDev.properties.loginServer

@description('Output the login server property for Prod ACR')
output acrProdLoginServer string = acrResourceProd.properties.loginServer
