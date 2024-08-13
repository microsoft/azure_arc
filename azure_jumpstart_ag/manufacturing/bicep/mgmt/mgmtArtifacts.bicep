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

@description('Suffix of Data Collection Rule for VM Insights: MSVMI-PerfandDa-"suffix"')
param VMIDCRName string = 'Agora'

var security = {
  name: 'Security(${workspaceName})'
  galleryName: 'Security'
}

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

module policyDeploymentRGScope './policyAzureArcRGScope.bicep' = {
  name: 'policyDeployment'
  params: {
    azureLocation: location
    VMInsightsDCRId: VMI_DCR_Deployment.outputs.id
  }
}

module VMI_DCR_Deployment './VMInsightsDCR.bicep' = {
  name: 'VMI-DCR-Deployment-${uniqueString(VMIDCRName)}'
  params: {
    DcrName: VMIDCRName
    WorkspaceLocation: location
    WorkspaceResourceId: workspace.id
  }
}
