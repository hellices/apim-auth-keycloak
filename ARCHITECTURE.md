# Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                           │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  Resource Group                                                │ │
│  │                                                                │ │
│  │  ┌──────────────────────┐         ┌─────────────────────────┐ │ │
│  │  │   AKS Cluster        │         │  Azure Container        │ │ │
│  │  │                      │◄────────┤  Registry (ACR)         │ │ │
│  │  │  ┌────────────────┐  │         │                         │ │ │
│  │  │  │   Keycloak     │  │         └─────────────────────────┘ │ │
│  │  │  │   + PostgreSQL │  │                                     │ │
│  │  │  │   (Namespace)  │  │                                     │ │
│  │  │  └────────────────┘  │                                     │ │
│  │  │                      │                                     │ │
│  │  │  LoadBalancer Service│                                     │ │
│  │  │  External IP         │                                     │ │
│  │  └──────────────────────┘                                     │ │
│  │            │                                                  │ │
│  │            │ OIDC/JWT Tokens                                 │ │
│  │            ▼                                                  │ │
│  │  ┌──────────────────────┐                                    │ │
│  │  │  API Management      │                                    │ │
│  │  │  (APIM)              │                                    │ │
│  │  │                      │                                    │ │
│  │  │  ┌────────────────┐  │                                    │ │
│  │  │  │ JWT Validation │  │                                    │ │
│  │  │  │ Policy         │  │                                    │ │
│  │  │  └────────────────┘  │                                    │ │
│  │  │  ┌────────────────┐  │                                    │ │
│  │  │  │ Rate Limiting  │  │                                    │ │
│  │  │  └────────────────┘  │                                    │ │
│  │  └──────────────────────┘                                    │ │
│  │            │                                                  │ │
│  │            │ Validated Requests                              │ │
│  │            ▼                                                  │ │
│  │  ┌──────────────────────┐                                    │ │
│  │  │  Azure OpenAI        │                                    │ │
│  │  │  (AI Foundry)        │                                    │ │
│  │  │                      │                                    │ │
│  │  │  ┌────────────────┐  │                                    │ │
│  │  │  │   GPT-4 Model  │  │                                    │ │
│  │  │  └────────────────┘  │                                    │ │
│  │  └──────────────────────┘                                    │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
            ▲                                    │
            │                                    │
            │ 1. Get JWT Token                   │ 2. API Request with Token
            │                                    │
      ┌─────┴─────┐                        ┌─────▼─────┐
      │   User    │                        │  Client   │
      │  Browser  │                        │    App    │
      └───────────┘                        └───────────┘
```

## Authentication Flow

```
┌────────┐         ┌──────────┐         ┌──────┐         ┌────────────┐
│  User  │         │ Keycloak │         │ APIM │         │   OpenAI   │
└────┬───┘         └────┬─────┘         └───┬──┘         └─────┬──────┘
     │                  │                   │                   │
     │ 1. POST /token   │                   │                   │
     ├─────────────────►│                   │                   │
     │  (credentials)   │                   │                   │
     │                  │                   │                   │
     │ 2. JWT Token     │                   │                   │
     │◄─────────────────┤                   │                   │
     │                  │                   │                   │
     │ 3. POST /openai/deployments/...      │                   │
     │    Authorization: Bearer <token>     │                   │
     ├──────────────────┴──────────────────►│                   │
     │                                      │                   │
     │                  4. Validate JWT     │                   │
     │                      (JWKS)          │                   │
     │                  ┌──────────────────►│                   │
     │                  │   Check issuer    │                   │
     │                  │   Check audience  │                   │
     │                  │   Check signature │                   │
     │                  └──────────────────┐│                   │
     │                                      ││                   │
     │                  5. Forward Request  │                   │
     │                     (with api-key)   │                   │
     │                                      ├──────────────────►│
     │                                      │                   │
     │                  6. OpenAI Response  │                   │
     │                                      │◄──────────────────┤
     │                                      │                   │
     │ 7. Return Response                   │                   │
     │◄─────────────────────────────────────┤                   │
     │                                      │                   │
```

## Component Details

### Keycloak (Identity Provider)
- **Location**: AKS Cluster
- **Database**: PostgreSQL
- **Exposed**: LoadBalancer Service (External IP)
- **Function**: User authentication, JWT token issuance
- **Realm**: `apim`
- **Client**: `apim-client`

### API Management (Gateway)
- **SKU**: Developer (configurable)
- **Function**: API Gateway with JWT validation
- **Policies**:
  - JWT validation with Keycloak
  - Rate limiting (100 req/min per user)
  - Backend routing to OpenAI
  - CORS handling

### Azure OpenAI (Backend Service)
- **Function**: AI model hosting
- **Models**: GPT-4 (configurable)
- **API**: Chat completions, Completions
- **Access**: Via APIM only (secured)

### Security Components
1. **JWT Validation**: Validates token signature, issuer, audience
2. **Rate Limiting**: Per-user quota enforcement
3. **API Key Management**: OpenAI key stored in APIM named values
4. **Network Security**: AKS with network policies, ACR integration

## Data Flow

1. **Authentication Phase**:
   - User → Keycloak: Username/Password
   - Keycloak → User: JWT Token (with claims)

2. **Authorization Phase**:
   - User → APIM: API Request + JWT Token
   - APIM → Keycloak JWKS: Public key for validation
   - APIM: Validate token signature, issuer, audience, expiration

3. **API Call Phase**:
   - APIM → OpenAI: Forwarded request with OpenAI API key
   - OpenAI → APIM: AI model response
   - APIM → User: Proxied response

## Deployment Sequence

1. **Infrastructure** (azd):
   - Resource Group
   - AKS Cluster
   - Container Registry
   - APIM Service
   - OpenAI Service

2. **Keycloak** (kubectl):
   - PostgreSQL Deployment
   - Keycloak Deployment
   - LoadBalancer Service

3. **Configuration** (Manual + Scripts):
   - Keycloak realm and client
   - APIM named values
   - APIM API import
   - APIM policies

## Network Architecture

```
Internet
   │
   ├─────► Keycloak LoadBalancer (8080)
   │         │
   │         └─► AKS Internal Network
   │               └─► Keycloak Pod
   │                     └─► PostgreSQL Pod
   │
   └─────► APIM Gateway (443)
             │
             └─► Azure OpenAI Endpoint (443)
```

## Scaling Considerations

- **Keycloak**: Scale deployment replicas in AKS
- **APIM**: Upgrade SKU or add units
- **OpenAI**: Scale via capacity units
- **Database**: Use Azure Database for PostgreSQL for production
