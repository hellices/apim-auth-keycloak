param name string
param location string = resourceGroup().location
param tags object = {}

@description('The email address of the publisher')
param publisherEmail string

@description('The name of the publisher')
param publisherName string

@description('The SKU of the APIM service')
param sku object = {
  name: 'Developer'
  capacity: 1
}

@description('Endpoint of the OpenAI service')
param openAiEndpoint string

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: sku
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Named value for OpenAI endpoint
resource openAiEndpointNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apimService
  name: 'openai-endpoint'
  properties: {
    displayName: 'openai-endpoint'
    value: openAiEndpoint
    secret: false
  }
}

// Named value for OpenAI key (placeholder - will be set manually)
resource openAiKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apimService
  name: 'openai-key'
  properties: {
    displayName: 'openai-key'
    value: 'placeholder-key-to-be-updated'
    secret: true
  }
}

// Named value for Keycloak issuer URL (placeholder - will be configured after Keycloak setup)
resource keycloakIssuerNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apimService
  name: 'keycloak-issuer-url'
  properties: {
    displayName: 'keycloak-issuer-url'
    value: 'https://keycloak.example.com/realms/apim'
    secret: false
  }
}

// Named value for Keycloak JWKS URL (placeholder - will be configured after Keycloak setup)
resource keycloakJwksNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apimService
  name: 'keycloak-jwks-url'
  properties: {
    displayName: 'keycloak-jwks-url'
    value: 'https://keycloak.example.com/realms/apim/protocol/openid-connect/certs'
    secret: false
  }
}

output name string = apimService.name
output id string = apimService.id
output gatewayUrl string = apimService.properties.gatewayUrl
