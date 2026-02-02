targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters
@description('Name of the resource group')
param resourceGroupName string = ''

@description('Name of the AKS cluster')
param aksClusterName string = ''

@description('Name of the API Management service')
param apimServiceName string = ''

@description('Name of the Azure OpenAI service')
param openAiServiceName string = ''

@description('Name of the Container Registry')
param containerRegistryName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Container Registry
module containerRegistry './core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// AKS Cluster
module aks './core/host/aks.bicep' = {
  name: 'aks'
  scope: rg
  params: {
    name: !empty(aksClusterName) ? aksClusterName : '${abbrs.containerServiceManagedClusters}${resourceToken}'
    location: location
    tags: tags
    acrName: containerRegistry.outputs.name
  }
}

// Azure OpenAI Service
module openAi './core/ai/openai.bicep' = {
  name: 'openai'
  scope: rg
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    deployments: [
      {
        name: 'gpt-4'
        model: {
          format: 'OpenAI'
          name: 'gpt-4'
          version: '0613'
        }
        sku: {
          name: 'Standard'
          capacity: 10
        }
      }
    ]
  }
}

// API Management
module apim './core/gateway/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso'
    openAiEndpoint: openAi.outputs.endpoint
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output AKS_CLUSTER_NAME string = aks.outputs.name
output ACR_LOGIN_SERVER string = containerRegistry.outputs.loginServer
output ACR_NAME string = containerRegistry.outputs.name

output APIM_SERVICE_NAME string = apim.outputs.name
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl

output OPENAI_SERVICE_NAME string = openAi.outputs.name
output OPENAI_ENDPOINT string = openAi.outputs.endpoint
