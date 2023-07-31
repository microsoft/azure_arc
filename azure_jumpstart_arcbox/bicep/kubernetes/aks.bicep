@description('The name of the Kubernetes cluster resource')
param aksClusterName string = 'ArcBox-AKS-Data'

@description('The name of the Kubernetes cluster resource')
param drClusterName string = 'ArcBox-AKS-DR-Data'

@description('The location of the Managed Cluster resource')
param location string = resourceGroup().location

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN')
param dnsPrefixPrimary string = 'arcdata'

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN')
param dnsPrefixSecondary string = 'arcdata'

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@description('The number of nodes for the cluster')
@minValue(1)
@maxValue(50)
param agentCount int = 3

@description('The size of the Virtual Machine')
param agentVMSize string = 'Standard_D8s_v4'

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

@description('The type of operating system')
@allowed([
  'Linux'
])
param osType string = 'Linux'

@description('The version of Kubernetes')
param kubernetesVersion string = '1.25.6'

var serviceCidr_primary = '10.20.64.0/19'
var dnsServiceIP_primary = '10.20.64.10'
var dockerBridgeCidr_primary = '172.17.0.1/16'
var serviceCidr_secondary = '172.20.64.0/19'
var dnsServiceIP_secondary = '172.20.64.10'
var dockerBridgeCidr_secondary = '192.168.0.1/16'
var virtualNetworkName = 'ArcBox-VNet'
var aksSubnetName = 'ArcBox-AKS-Subnet'
var drVirtualNetworkName = 'ArcBox-DR-VNet'
var drSubnetName = 'ArcBox-DR-Subnet'

resource aksClusterName_resource 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  location: location
  name: aksClusterName
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    dnsPrefix: dnsPrefixPrimary
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
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, aksSubnetName)
      }
    ]
    storageProfile:{
      diskCSIDriver: {
        enabled: true
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: serviceCidr_primary
      dnsServiceIP: dnsServiceIP_primary
      dockerBridgeCidr: dockerBridgeCidr_primary
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

resource drClusterName_resource 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  location: location
  name: drClusterName
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    dnsPrefix: dnsPrefixSecondary
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
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', drVirtualNetworkName, drSubnetName)
      }
    ]
    storageProfile:{
      diskCSIDriver: {
        enabled: true
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: serviceCidr_secondary
      dnsServiceIP: dnsServiceIP_secondary
      dockerBridgeCidr: dockerBridgeCidr_secondary
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
