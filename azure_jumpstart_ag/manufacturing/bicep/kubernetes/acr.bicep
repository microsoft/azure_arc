@description('The location of the Managed Cluster resource')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('Name of the Azure Container Registry')
param acrName string

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' ={
  name: acrName
  location: location
  tags: resourceTags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}
