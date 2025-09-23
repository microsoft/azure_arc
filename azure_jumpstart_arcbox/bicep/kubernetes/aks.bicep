@description('The name of the Kubernetes cluster resource')
param aksClusterName string = '${namingPrefix}-AKS-Data'

@description('The name of the Kubernetes cluster resource')
param drClusterName string = '${namingPrefix}-AKS-DR-Data'

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

@description('RSA public key used for securing SSH access to ArcBox resources. This parameter is only needed when deploying the DataOps or DevOps flavors.')
@secure()
param sshRSAPublicKey string = ''

@description('boolean flag to turn on and off of RBAC')
param enableRBAC bool = true

@description('The type of operating system')
@allowed([
  'Linux'
])
param osType string = 'Linux'

@description('The version of Kubernetes')
param kubernetesVersion string = '1.31.3'

@maxLength(7)
@description('The naming prefix for the nested virtual machines. Example: ArcBox-Win2k19')
param namingPrefix string = 'ArcBox'

var serviceCidr_primary = '10.20.64.0/19'
var dnsServiceIP_primary = '10.20.64.10'
var serviceCidr_secondary = '172.20.64.0/19'
var dnsServiceIP_secondary = '172.20.64.10'
var virtualNetworkName = '${namingPrefix}-VNet'
var aksSubnetName = '${namingPrefix}-AKS-Subnet'
var drVirtualNetworkName = '${namingPrefix}-DR-VNet'
var drSubnetName = '${namingPrefix}-DR-Subnet'

resource aksClusterName_resource 'Microsoft.ContainerService/managedClusters@2025-05-02-preview' = {
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
      outboundType: 'userAssignedNATGateway'
    }
    autoUpgradeProfile: {
      nodeOSUpgradeChannel: 'NodeImage'
      upgradeChannel: 'stable'
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
  }
}

resource drClusterName_resource 'Microsoft.ContainerService/managedClusters@2024-09-02-preview' = {
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
      outboundType: 'userAssignedNATGateway'
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
    autoUpgradeProfile: {
      nodeOSUpgradeChannel: 'NodeImage'
      upgradeChannel: 'stable'
    }
  }
}

// Add role assignment for the AKS cluster: Owner role
resource aksRoleAssignment_Owner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksClusterName_resource.id, 'Microsoft.Authorization/roleAssignments', 'Owner')
  scope: resourceGroup()
  properties: {
    principalId: aksClusterName_resource.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalType: 'ServicePrincipal'
  }
}

// Add role assignment for the AKS DR cluster: Owner role
resource aksDRRoleAssignment_Owner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(drClusterName_resource.id, 'Microsoft.Authorization/roleAssignments', 'Owner')
  scope: resourceGroup()
  properties: {
    principalId: drClusterName_resource.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalType: 'ServicePrincipal'
  }
}
