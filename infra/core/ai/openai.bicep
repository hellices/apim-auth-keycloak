param name string
param location string = resourceGroup().location
param tags object = {}

@description('Azure OpenAI deployments')
param deployments array = []

@description('The SKU of the OpenAI service')
param sku object = {
  name: 'S0'
}

resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: sku
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: openAi
  name: deployment.name
  sku: deployment.sku
  properties: {
    model: deployment.model
  }
}]

output name string = openAi.name
output id string = openAi.id
output endpoint string = openAi.properties.endpoint
output key string = openAi.listKeys().key1
