# APIM Authentication with Keycloak

Azure API Management (APIM) authentication integration with Keycloak for securing Azure OpenAI API access.

## Overview

This project demonstrates how to set up a complete authentication flow where:
1. **Keycloak** runs on Azure Kubernetes Service (AKS) as an identity provider (simulating on-premise environment)
2. **Azure API Management (APIM)** acts as a gateway for Azure OpenAI (AI Foundry) models
3. **JWT token validation** ensures only authenticated users from Keycloak can access the APIs

## Architecture

```
┌─────────┐      ┌──────────────┐      ┌──────────┐      ┌────────────────┐
│  User   │─────▶│  Keycloak    │─────▶│   APIM   │─────▶│  Azure OpenAI  │
│         │      │  (on AKS)    │      │ Gateway  │      │  (AI Foundry)  │
└─────────┘      └──────────────┘      └──────────┘      └────────────────┘
             1. Authenticate        2. Validate JWT   3. Forward Request
                Get JWT Token          with Policy
```

## Features

- ✅ **Keycloak on AKS**: Complete Keycloak deployment with PostgreSQL backend
- ✅ **Azure Infrastructure**: Bicep templates for automated deployment with `azd`
- ✅ **JWT Validation**: APIM policy for Keycloak token validation
- ✅ **Azure OpenAI Integration**: Proxy Azure OpenAI models through APIM
- ✅ **Rate Limiting**: Per-user rate limiting (100 requests/minute)
- ✅ **Security**: Bearer token authentication with role-based access

## Quick Start

### Prerequisites

- Azure CLI (`az`)
- Azure Developer CLI (`azd`)
- kubectl
- Azure subscription

### Deploy

```bash
# 1. Clone the repository
git clone https://github.com/hellices/apim-auth-keycloak.git
cd apim-auth-keycloak

# 2. Login and deploy infrastructure
azd auth login
azd up

# 3. Deploy Keycloak on AKS
az aks get-credentials --resource-group <rg-name> --name <aks-name>
kubectl apply -f kubernetes/keycloak-deployment.yaml

# 4. Configure Keycloak and APIM
# Follow detailed instructions in SETUP.md
```

## Documentation

- **[SETUP.md](./SETUP.md)**: Complete step-by-step setup guide
- **Infrastructure**: Bicep templates in `infra/` directory
- **Kubernetes**: Keycloak deployment manifests in `kubernetes/` directory
- **APIM Policies**: API policies and OpenAPI spec in `apim-policies/` directory

## Project Structure

```
.
├── azure.yaml                          # Azure Developer CLI configuration
├── infra/                              # Bicep infrastructure templates
│   ├── main.bicep                      # Main infrastructure definition
│   ├── abbreviations.json              # Azure resource naming conventions
│   └── core/
│       ├── host/
│       │   ├── aks.bicep              # AKS cluster
│       │   └── container-registry.bicep
│       ├── ai/
│       │   └── openai.bicep           # Azure OpenAI service
│       └── gateway/
│           └── apim.bicep             # API Management
├── kubernetes/
│   └── keycloak-deployment.yaml       # Keycloak K8s manifests
├── apim-policies/
│   ├── openai-api-policy.xml          # JWT validation policy
│   └── openai-api-spec.json           # OpenAPI specification
├── SETUP.md                           # Detailed setup guide
└── README.md                          # This file
```

## Key Components

### 1. Azure Infrastructure (azd + Bicep)

- **AKS Cluster**: Hosts Keycloak (simulating on-premise environment)
- **Container Registry**: For custom container images
- **API Management**: Gateway with JWT validation
- **Azure OpenAI**: AI Foundry models (GPT-4)

### 2. Keycloak (Manual Setup on AKS)

- PostgreSQL database for persistence
- Keycloak realm: `apim`
- Client ID: `apim-client`
- User authentication with JWT token issuance

### 3. APIM Configuration (Manual)

- JWT validation policy with Keycloak integration
- OpenAI API proxy
- Rate limiting per user
- CORS configuration

## Testing

### Get Token from Keycloak

```bash
curl -X POST "http://<KEYCLOAK_IP>:8080/realms/apim/protocol/openid-connect/token" \
  -d "client_id=apim-client" \
  -d "client_secret=<SECRET>" \
  -d "grant_type=password" \
  -d "username=testuser" \
  -d "password=Test123!"
```

### Call Azure OpenAI via APIM

```bash
curl -X POST "<APIM_URL>/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

## Security Features

- **JWT Token Validation**: All requests validated against Keycloak
- **Rate Limiting**: 100 requests per minute per user
- **CORS Configuration**: Configurable cross-origin access
- **Secret Management**: API keys stored securely in APIM
- **Role-Based Access**: Configurable via Keycloak realm roles

## Clean Up

```bash
azd down --force --purge
```

## References

- [Azure API Management OAuth 2.0](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-oauth2)
- [APIM Authentication Overview](https://learn.microsoft.com/en-us/azure/api-management/authentication-authorization-overview)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)

## License

MIT

## Contributing

Contributions welcome! Please open an issue or submit a pull request.
