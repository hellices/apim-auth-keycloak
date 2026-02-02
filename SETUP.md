# Setup Guide: Keycloak Authentication with Azure APIM for AI Foundry

This guide walks you through setting up a complete authentication flow where users authenticate via Keycloak (running on AKS) and access Azure OpenAI models through Azure API Management.

## Architecture Overview

```
User → Keycloak (AKS) → Get JWT Token → APIM (JWT Validation) → Azure OpenAI
```

## Prerequisites

- Azure CLI (`az`) installed
- Azure Developer CLI (`azd`) installed
- kubectl installed
- An Azure subscription with permissions to create resources
- Docker (optional, for local testing)

## Part 1: Deploy Azure Infrastructure with azd

### 1.1 Initialize and Deploy

```bash
# Login to Azure
az login
azd auth login

# Set environment variables
azd env new <environment-name>
azd env set AZURE_LOCATION "koreacentral"

# Deploy infrastructure
azd up
```

This will deploy:
- Azure Kubernetes Service (AKS)
- Azure Container Registry (ACR)
- Azure API Management (APIM)
- Azure OpenAI Service with GPT-4 deployment

### 1.2 Save Output Values

After deployment, save the output values:

```bash
# Get output values
azd env get-values

# Save specific values for later use
export RESOURCE_GROUP=$(azd env get-value AZURE_RESOURCE_GROUP)
export AKS_NAME=$(azd env get-value AKS_CLUSTER_NAME)
export APIM_NAME=$(azd env get-value APIM_SERVICE_NAME)
export OPENAI_NAME=$(azd env get-value OPENAI_SERVICE_NAME)
export APIM_GATEWAY_URL=$(azd env get-value APIM_GATEWAY_URL)
```

## Part 2: Deploy Keycloak on AKS

### 2.1 Connect to AKS Cluster

```bash
# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME

# Verify connection
kubectl get nodes
```

### 2.2 Deploy Keycloak

```bash
# Apply Keycloak deployment
kubectl apply -f kubernetes/keycloak-deployment.yaml

# Wait for Keycloak to be ready (this may take 5-10 minutes)
kubectl wait --for=condition=available --timeout=600s deployment/keycloak -n keycloak

# Get Keycloak service external IP
kubectl get svc keycloak -n keycloak

# Wait until EXTERNAL-IP is assigned (not <pending>)
# This may take a few minutes
export KEYCLOAK_URL=$(kubectl get svc keycloak -n keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Keycloak URL: http://$KEYCLOAK_URL:8080"
```

### 2.3 Access Keycloak Admin Console

1. Open browser and navigate to: `http://<KEYCLOAK_EXTERNAL_IP>:8080`
2. Click on "Administration Console"
3. Login with:
   - Username: `admin`
   - Password: `admin`

## Part 3: Configure Keycloak

### 3.1 Create a New Realm

1. In Keycloak Admin Console, hover over "Master" dropdown (top-left)
2. Click "Create Realm"
3. Set Realm name: `apim`
4. Click "Create"

### 3.2 Create a Client for APIM

1. In the `apim` realm, go to "Clients" → "Create client"
2. Set the following:
   - Client ID: `apim-client`
   - Client Protocol: `openid-connect`
   - Click "Next"
3. Configure client settings:
   - Client authentication: `ON`
   - Authorization: `OFF`
   - Authentication flow:
     - ✓ Standard flow
     - ✓ Direct access grants
   - Click "Next"
4. Set Valid redirect URIs:
   - `https://oauth.pstmn.io/v1/callback` (for Postman testing)
   - `http://localhost:*` (for local testing)
   - Click "Save"

### 3.3 Get Client Secret

1. Go to "Clients" → `apim-client` → "Credentials" tab
2. Copy the "Client secret" value
3. Save this for later use

### 3.4 Create a Test User

1. Go to "Users" → "Add user"
2. Set:
   - Username: `testuser`
   - Email: `testuser@example.com`
   - First name: `Test`
   - Last name: `User`
   - Email verified: `ON`
   - Click "Create"
3. Go to "Credentials" tab
4. Click "Set password"
5. Set password: `Test123!`
6. Set "Temporary": `OFF`
7. Click "Save"

### 3.5 Configure Realm Roles (Optional)

1. Go to "Realm roles" → "Create role"
2. Set Role name: `api-user`
3. Click "Save"
4. Go to "Users" → Select `testuser` → "Role mapping" tab
5. Click "Assign role"
6. Select `api-user` and click "Assign"

## Part 4: Configure Azure API Management

### 4.1 Update APIM Named Values with Keycloak URLs

```bash
# Get Keycloak realm configuration
export KEYCLOAK_ISSUER="http://$KEYCLOAK_URL:8080/realms/apim"
export KEYCLOAK_JWKS="http://$KEYCLOAK_URL:8080/realms/apim/protocol/openid-connect/certs"

# Update APIM named values
az apim nv update \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --named-value-id keycloak-issuer-url \
  --value "$KEYCLOAK_ISSUER"

az apim nv update \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --named-value-id keycloak-jwks-url \
  --value "$KEYCLOAK_JWKS"
```

### 4.2 Update OpenAI API Key in APIM

```bash
# Get OpenAI API key
export OPENAI_KEY=$(az cognitiveservices account keys list \
  --resource-group $RESOURCE_GROUP \
  --name $OPENAI_NAME \
  --query "key1" -o tsv)

# Update APIM named value
az apim nv update \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --named-value-id openai-key \
  --value "$OPENAI_KEY" \
  --secret true
```

### 4.3 Import OpenAI API to APIM

1. Open Azure Portal → Navigate to your APIM instance
2. Go to "APIs" → "Add API" → "OpenAPI"
3. Select "Full" (not Link)
4. Upload the file: `apim-policies/openai-api-spec.json`
5. Set:
   - Display name: `Azure OpenAI API`
   - Name: `openai-api`
   - API URL suffix: `openai`
6. Click "Create"

### 4.4 Apply JWT Validation Policy

1. In APIM, go to "APIs" → Select "Azure OpenAI API"
2. Go to "Design" tab → Select "All operations"
3. In the "Inbound processing" section, click "< / >" (Policy code editor)
4. Replace the content with the policy from: `apim-policies/openai-api-policy.xml`
5. Update the policy to use your Keycloak URLs:
   - Replace `{{keycloak-issuer-url}}` references if needed
6. Click "Save"

## Part 5: Testing the Integration

### 5.1 Get Access Token from Keycloak

Using curl:

```bash
# Get access token
export KEYCLOAK_TOKEN=$(curl -X POST \
  "http://$KEYCLOAK_URL:8080/realms/apim/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=apim-client" \
  -d "client_secret=<YOUR_CLIENT_SECRET>" \
  -d "grant_type=password" \
  -d "username=testuser" \
  -d "password=Test123!" \
  | jq -r '.access_token')

echo "Access Token: $KEYCLOAK_TOKEN"
```

Using Postman:
1. Create a new request
2. Authorization tab → Type: OAuth 2.0
3. Configure New Token:
   - Token Name: `Keycloak Token`
   - Grant Type: `Password Credentials`
   - Access Token URL: `http://<KEYCLOAK_IP>:8080/realms/apim/protocol/openid-connect/token`
   - Client ID: `apim-client`
   - Client Secret: `<YOUR_CLIENT_SECRET>`
   - Username: `testuser`
   - Password: `Test123!`
4. Click "Get New Access Token"

### 5.2 Call Azure OpenAI through APIM

```bash
# Test the API
curl -X POST \
  "$APIM_GATEWAY_URL/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
  -H "Authorization: Bearer $KEYCLOAK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful assistant."
      },
      {
        "role": "user",
        "content": "Hello! Can you tell me a short joke?"
      }
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### 5.3 Test Authentication Failure

Try calling without token (should return 401):

```bash
curl -X POST \
  "$APIM_GATEWAY_URL/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Part 6: Validation and Monitoring

### 6.1 Check APIM Analytics

1. In Azure Portal, go to your APIM instance
2. Navigate to "Analytics" → "APIs"
3. View request counts, response times, and errors

### 6.2 Check Keycloak Sessions

1. In Keycloak Admin Console
2. Go to "Sessions" (under Manage)
3. View active user sessions

### 6.3 Test Token Expiration

Keycloak tokens expire after a certain time (default 5 minutes). After expiration:
- API calls will fail with 401
- User needs to request a new token

## Troubleshooting

### Keycloak Pod Not Starting

```bash
# Check pod status
kubectl get pods -n keycloak

# Check pod logs
kubectl logs -f deployment/keycloak -n keycloak

# Check events
kubectl get events -n keycloak --sort-by='.lastTimestamp'
```

### APIM JWT Validation Failing

1. Verify Keycloak issuer URL is correct
2. Check that JWKS URL is accessible from APIM
3. Verify audience matches client ID in token
4. Check APIM trace logs:
   - In APIM, enable "Trace" on the API operation
   - Add header: `Ocp-Apim-Trace: true`
   - Check trace details in response

### Cannot Access OpenAI

1. Verify OpenAI key is correct in APIM named values
2. Check OpenAI endpoint URL
3. Verify OpenAI deployment name matches in API call

## Security Best Practices

1. **Use HTTPS for Production**: Configure TLS/SSL for both Keycloak and APIM
2. **Restrict Network Access**: Use Azure Private Link for APIM and OpenAI
3. **Rotate Secrets**: Regularly rotate client secrets and API keys
4. **Enable Logging**: Configure diagnostic logs for APIM and AKS
5. **Use Azure Key Vault**: Store secrets in Key Vault and reference in APIM
6. **Implement Rate Limiting**: Already configured in the policy (100 calls/minute per user)
7. **Regular Updates**: Keep Keycloak and AKS up to date

## Clean Up

To remove all resources:

```bash
# Delete Azure resources
azd down --force --purge

# Or delete resource group manually
az group delete --name $RESOURCE_GROUP --yes
```

## Next Steps

1. Configure custom domain for Keycloak with TLS certificate
2. Set up Azure Front Door or Application Gateway for better security
3. Implement refresh token flow for better user experience
4. Add more OpenAI models and endpoints
5. Configure Azure Monitor alerts for API failures
6. Set up Azure Log Analytics for centralized logging

## References

- [Azure API Management OAuth 2.0 Configuration](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-oauth2)
- [APIM Authentication and Authorization](https://learn.microsoft.com/en-us/azure/api-management/authentication-authorization-overview)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
