@description('Name for your log analytics workspace')
param workspaceName string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('SKU, leave default pergb2018')
param sku string = 'pergb2018'

var security = {
  name: 'Security(${workspaceName})'
  galleryName: 'Security'
}

var automationAccountName = 'Ag-Automation-${uniqueString(resourceGroup().id)}'
var automationAccountLocation = ((location == 'eastus') ? 'eastus2' : ((location == 'eastus2') ? 'eastus' : location))

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: sku
    }
  }
}

resource VMInsightsMicrosoftOperationalInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  location: location
  name: 'VMInsights(${split(workspace.id, '/')[8]})'
  tags: resourceTags
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

resource securityGallery 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: security.name
  location: location
  tags: resourceTags
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

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: automationAccountName
  location: automationAccountLocation
  tags: resourceTags
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  dependsOn: [
    workspace
  ]
}

resource workspaceAutomation 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-08-01' = {
  parent: workspace
  name: 'Automation'
  tags: resourceTags
  properties: {
    resourceId: automationAccount.id
  }
}
