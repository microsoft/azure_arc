@description('The name of the Staging Kubernetes cluster resource')
param aksStagingClusterName string

@description('The location of the Managed Cluster resource')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN staging')
param dnsPrefixStaging string = 'Ag-staging'

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

@description('The name of the staging aks subnet')
param aksSubnetNameStaging string

@minLength(5)
@maxLength(50)
@description('Name of the production Azure Container Registry')
param acrNameProd string

@minLength(5)
@maxLength(50)
@description('Name of the Staging Azure Container Registry')
param acrNameStaging string

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

@description('The type of operating system')
@allowed([
  'Linux'
])
param osType string = 'Linux'
var tier  = 'free'

@description('The version of Kubernetes')
param kubernetesVersion string = '1.24.9'

var serviceCidr_staging = '10.21.64.0/19'
var dnsServiceIP_staging = '10.21.64.10'
var dockerBridgeCidr_staging = '172.18.0.1/16'

resource aksStaging 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  location: location
  name: aksStagingClusterName
  tags: resourceTags
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
    dnsPrefix: dnsPrefixStaging
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
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkNameCloud, aksSubnetNameStaging)
      }
    ]
    storageProfile:{
      diskCSIDriver: {
        enabled: true
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: serviceCidr_staging
      dnsServiceIP: dnsServiceIP_staging
      dockerBridgeCidr: dockerBridgeCidr_staging
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

resource acrResourceProd 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = if (false) {
  name: acrNameProd
  location: location
  tags: resourceTags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource acrResourceStaging 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrNameStaging
  location: location
  tags: resourceTags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

@description('Output the login server property for Dev ACR')
output acrStagingName string = acrResourceStaging.name

@description('Output the login server property for Prod ACR')
output acrProdName string = acrResourceProd.name
