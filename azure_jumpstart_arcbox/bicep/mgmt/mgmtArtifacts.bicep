@description('Name of the VNet')
param virtualNetworkName string = 'ArcBox-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'ArcBox-Subnet'

@description('Name for your log analytics workspace')
param workspaceName string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('SKU, leave default pergb2018')
param sku string = 'pergb2018'

@description('The base URL used for accessing templates and automation artifacts. Typically inherited from parent ARM template.')
param templateBaseUrl string

var Updates = {
  name: 'Updates(${workspaceName})'
  galleryName: 'Updates'
}
var ChangeTracking = {
  name: 'ChangeTracking(${workspaceName})'
  galleryName: 'ChangeTracking'
}
var Security = {
  name: 'Security(${workspaceName})'
  galleryName: 'Security'
}
var policyTemplate = uri(templateBaseUrl, 'mgmt/policyAzureArcBuiltins.json')
var monitorWorkbookTemplate = uri(templateBaseUrl, 'mgmt/mgmtMonitorWorkbook.json')
var dashboardTemplate = uri(templateBaseUrl, 'mgmt/mgmtDashboard.json')
var automationAccountName_var = 'ArcBox-Automation-${uniqueString(resourceGroup().id)}'
var subnetAddressPrefix = '172.16.1.0/24'
var addressPrefix = '172.16.0.0/16'
var automationAccountLocation = ((location == 'eastus') ? 'eastus2' : ((location == 'eastus2') ? 'eastus' : location))

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2019-04-01' = {
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

resource workspaceName_resource 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: sku
    }
  }
}

resource Updates_name 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  location: location
  name: Updates.name
  properties: {
    workspaceResourceId: workspaceName_resource.id
  }
  plan: {
    name: Updates.name
    publisher: 'Microsoft'
    promotionCode: ''
    product: 'OMSGallery/${Updates.galleryName}'
  }
}

resource VMInsights_Microsoft_OperationalInsights_workspaces_workspaceName_8 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  location: location
  name: 'VMInsights(${split(workspaceName_resource.id, '/')[8]})'
  properties: {
    workspaceResourceId: workspaceName_resource.id
  }
  plan: {
    name: 'VMInsights(${split(workspaceName_resource.id, '/')[8]})'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource ChangeTracking_name 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: ChangeTracking.name
  location: location
  plan: {
    name: 'ChangeTracking(${split(workspaceName_resource.id, '/')[8]})'
    promotionCode: ''
    product: 'OMSGallery/${ChangeTracking.galleryName}'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: workspaceName_resource.id
  }
}

resource Security_name 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: Security.name
  location: location
  plan: {
    name: 'ChangeTracking(${split(workspaceName_resource.id, '/')[8]})'
    promotionCode: ''
    product: 'OMSGallery/${Security.galleryName}'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: workspaceName_resource.id
  }
}

resource automationAccountName 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: automationAccountName_var
  location: automationAccountLocation
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  dependsOn: [
    workspaceName_resource
  ]
}

resource workspaceName_Automation 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-03-01-preview' = {
  parent: workspaceName_resource
  name: 'Automation'
  location: location
  properties: {
    resourceId: automationAccountName.id
  }
}