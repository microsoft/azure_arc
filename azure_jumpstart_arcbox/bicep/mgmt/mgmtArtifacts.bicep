@description('Name of the VNet')
param virtualNetworkName string = 'ArcBox-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'ArcBox-Subnet'

@description('Name for your log analytics workspace')
param workspaceName string

@description('The flavor of ArcBox you want to deploy. Valid values are: \'Full\', \'ITPro\'')
@allowed([
  'Full'
  'ITPro'
  'DevOps'
])
param flavor string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('SKU, leave default pergb2018')
param sku string = 'pergb2018'

var updates = {
  name: 'Updates(${workspaceName})'
  galleryName: 'Updates'
}
var changeTracking = {
  name: 'ChangeTracking(${workspaceName})'
  galleryName: 'ChangeTracking'
}
var security = {
  name: 'Security(${workspaceName})'
  galleryName: 'Security'
}

var automationAccountName = 'ArcBox-Automation-${uniqueString(resourceGroup().id)}'
var subnetAddressPrefix = '172.16.1.0/24'
var addressPrefix = '172.16.0.0/16'
var automationAccountLocation = ((location == 'eastus') ? 'eastus2' : ((location == 'eastus2') ? 'eastus' : location))

resource arcVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: sku
    }
  }
}

resource updatesWorkpace 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  location: location
  name: updates.name
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: updates.name
    publisher: 'Microsoft'
    promotionCode: ''
    product: 'OMSGallery/${updates.galleryName}'
  }
}

resource VMInsightsMicrosoftOperationalInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  location: location
  name: 'VMInsights(${split(workspace.id, '/')[8]})'
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: 'VMInsights(${split(workspace.id, '/')[8]})'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource changeTrackingGallery 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: changeTracking.name
  location: location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: changeTracking.name
    promotionCode: ''
    product: 'OMSGallery/${changeTracking.galleryName}'
    publisher: 'Microsoft'
  }
}

resource securityGallery 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: security.name
  location: location
  properties: {
    workspaceResourceId: workspace.id
  }
  plan: {
    name: security.name
    promotionCode: ''
    product: 'OMSGallery/${security.galleryName}'
    publisher: 'Microsoft'
  }
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  location: automationAccountLocation
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  dependsOn: [
    workspace
  ]
}

resource workspaceAutomation 'Microsoft.OperationalInsights/workspaces/linkedServices@2015-11-01-preview' = {
  parent: workspace
  name: 'Automation'
  properties: {
    resourceId: automationAccount.id
  }
}

module policyDeployment './policyAzureArcITPro.bicep' = {
  name: 'policyDeployment'
  params: {
    azureLocation: location
    logAnalyticsWorkspaceId: workspace.id
    flavor: flavor
  }
}

output vnetId string = arcVirtualNetwork.id
output subnetId string = arcVirtualNetwork.properties.subnets[0].id
