# AI Foundry + OIDC (Keycloak) Integration via Azure APIM

This repository provides an example of integrating AI Foundry with OIDC authentication (Keycloak) through Azure API Management (APIM) for monitoring user login history and prompt usage.

[한국어 문서](./docs/README-ko.md)

## 🎯 Purpose

- Integrate OIDC (OpenID Connect) authentication with AI Foundry APIs
- Track user login history per user
- Monitor and audit AI prompt usage
- Centralized API management through APIM

## 📁 Project Structure

```
.
├── keycloak/                    # Keycloak configuration
│   ├── docker-compose.yml       # Keycloak local deployment
│   └── realm-export.json        # AI Foundry realm configuration
├── apim-policies/               # APIM policy files
│   ├── validate-oidc-token.xml  # OIDC token validation policy
│   ├── log-ai-prompts.xml       # AI prompt logging policy
│   └── combined-policy.xml      # Combined authentication + logging policy
├── sample-app/                  # Sample application
│   ├── main.py                  # Python client example
│   ├── requirements.txt         # Python dependencies
│   └── .env.example             # Environment variables template
└── docs/                        # Documentation
    ├── README-ko.md             # Korean documentation
    └── architecture.md          # Architecture documentation
```

## 🚀 Quick Start

### 1. Start Keycloak

```bash
cd keycloak
docker-compose up -d
```

Access Keycloak Admin Console: http://localhost:8080
- Admin credentials: admin / admin

### 2. Run Sample Application

```bash
cd sample-app
pip install -r requirements.txt
cp .env.example .env
# Edit .env file with your configuration
python main.py
```

## 🔧 Components

### Keycloak (OIDC Provider)

- **Realm**: `ai-foundry`
- **Client**: `ai-foundry-client`
- **User Roles**: `ai-user`, `ai-admin`
- **Test User**: `testuser` / `testpassword`

### Azure API Management Policies

1. **validate-oidc-token.xml**: JWT token validation and user information extraction
2. **log-ai-prompts.xml**: AI prompt request/response logging
3. **combined-policy.xml**: Combined authentication + logging policy

### Monitoring Data

The APIM policies capture and log the following data:

#### User Authentication Events
- User ID and email
- Authentication timestamp
- API path and method
- User roles

#### Prompt Usage
- User prompt content (truncated)
- Token usage (input/output)
- Response time
- Model used

## 📋 APIM Configuration Guide

### 1. Configure Named Values

Set up the following Named Values in APIM:

| Name | Example Value |
|------|---------------|
| `keycloak-openid-config-url` | `https://your-keycloak/realms/ai-foundry/.well-known/openid-configuration` |
| `keycloak-issuer-url` | `https://your-keycloak/realms/ai-foundry` |

### 2. Configure Event Hub Logger

For AI prompt logging, set up an Event Hub Logger:

1. Create Azure Event Hub
2. Create Logger in APIM (`ai-foundry-logger`)
3. Configure Event Hub connection string

### 3. Enable Application Insights

For detailed monitoring, integrate Application Insights with APIM.

## 🔐 Security Considerations

1. **Secret Management**: Store client secrets in Azure Key Vault
2. **Token Validation**: Validate issuer, audience, and expiration
3. **Prompt Logging**: Consider masking sensitive data
4. **Access Control**: Apply role-based access control (RBAC)

## 📊 Monitoring Dashboard

Using Event Hub or Application Insights data, you can visualize:

- API calls per user
- Token usage trends
- Response time analysis
- Error rate monitoring

Dashboard options:
- Azure Monitor Workbooks
- Power BI Dashboards
- Custom analytics tools

## 📄 Documentation

- [Architecture Overview](./docs/architecture.md)
- [한국어 문서](./docs/README-ko.md)

## 🤝 Contributing

Issues and pull requests are welcome.

## 📄 License

MIT License
