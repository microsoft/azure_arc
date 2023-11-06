@description('The name of the API Management service instance')
param apiManagementServiceName string = 'apiservice${uniqueString(resourceGroup().id)}'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Standard'
  'Premium'
])
param sku string = 'Developer'

@description('The instance size of this API Management service.')
@allowed([
  1
  2
])
param skuCount int = 1

@description('Location for all resources.')
param location string = resourceGroup().location

resource apiManagementService 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName

  }

}
resource apimAdventureWorkApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'AdventureworkWeatherAPI'
  parent: apiManagementService
  properties: {
    displayName: 'AdventureworkWeatherAPI'
    apiRevision: '1'
    subscriptionRequired: true
    path: 'adventurework'
    protocols: [
      'http'
      'https'
    ]
    authenticationSettings: {
      oAuth2AuthenticationSettings: []
      openidAuthenticationSettings: []
    }
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    isCurrent: true
    format: 'openapi+json'
    value: loadTextContent('adventurework.json')
  }
}
resource adventureWorkAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimAdventureWorkApi
  
  properties: {
    value: loadTextContent('adventurework.xml')
  }
}
resource selfHostGateway 'Microsoft.ApiManagement/service/gateways@2023-03-01-preview' = {
  name: 'selfhost'
  parent: apiManagementService
  properties: {
    locationData: {
      name: 'HCI'
    }
  }
}
output apiManagementServiceName string = apiManagementService.name





