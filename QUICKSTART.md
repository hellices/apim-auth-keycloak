# Quick Start Guide

Get up and running with Keycloak + APIM + Azure OpenAI in under 30 minutes.

## Prerequisites

Install required tools:
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- curl and jq (for testing)

## Step 1: Deploy Infrastructure (10 minutes)

```bash
# Clone repository
git clone https://github.com/hellices/apim-auth-keycloak.git
cd apim-auth-keycloak

# Login to Azure
az login
azd auth login

# Deploy infrastructure
azd up
# When prompted:
# - Choose a subscription
# - Enter environment name (e.g., "dev")
# - Choose location (e.g., "koreacentral")
```

Wait for deployment to complete (~10 minutes).

## Step 2: Deploy Keycloak (5 minutes)

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(azd env get-value AZURE_RESOURCE_GROUP) \
  --name $(azd env get-value AKS_CLUSTER_NAME)

# Deploy Keycloak
kubectl apply -f kubernetes/keycloak-deployment.yaml

# Wait for Keycloak to be ready
kubectl wait --for=condition=available --timeout=600s deployment/keycloak -n keycloak

# Get Keycloak URL
./scripts/get-keycloak-urls.sh
```

## Step 3: Configure Keycloak (10 minutes)

1. Open Keycloak Admin Console (URL from previous step)
2. Login: admin / admin
3. Create realm `apim`:
   - Hover "Master" → "Create Realm"
   - Name: `apim`
   - Click "Create"

4. Create client `apim-client`:
   - Clients → "Create client"
   - Client ID: `apim-client`
   - Next → Enable "Client authentication" → Next
   - Valid redirect URIs: `https://oauth.pstmn.io/v1/callback`, `http://localhost:*`
   - Save

5. Copy client secret:
   - Clients → `apim-client` → Credentials tab
   - Copy "Client secret"

6. Create test user:
   - Users → "Add user"
   - Username: `testuser`, Email: `testuser@example.com`
   - Create → Credentials tab → "Set password"
   - Password: `Test123!`, Temporary: OFF
   - Save

## Step 4: Configure APIM (5 minutes)

```bash
# Update APIM with Keycloak and OpenAI configuration
./scripts/configure-apim.sh
```

Then in Azure Portal:

1. Navigate to your APIM instance
2. APIs → "Add API" → "OpenAPI"
3. Upload `apim-policies/openai-api-spec.json`
4. Set API URL suffix: `openai`
5. Create
6. Select "All operations" → Policy code editor
7. Paste content from `apim-policies/openai-api-policy.xml`
8. Save

## Step 5: Test Integration (2 minutes)

```bash
# Run integration test
./scripts/test-integration.sh
```

Or manually:

```bash
# Get token
TOKEN=$(curl -X POST "http://<KEYCLOAK_IP>:8080/realms/apim/protocol/openid-connect/token" \
  -d "client_id=apim-client" \
  -d "client_secret=<SECRET>" \
  -d "grant_type=password" \
  -d "username=testuser" \
  -d "password=Test123!" \
  | jq -r '.access_token')

# Call API
curl -X POST "<APIM_URL>/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}],"max_tokens":50}'
```

## Success Criteria

✅ Keycloak is accessible and configured  
✅ Test user can obtain JWT token from Keycloak  
✅ API call without token returns 401  
✅ API call with valid token returns 200 and OpenAI response  

## Troubleshooting

### Deployment fails
```bash
azd down
azd up
```

### Keycloak not accessible
```bash
kubectl get pods -n keycloak
kubectl logs -f deployment/keycloak -n keycloak
```

### APIM returns 401 with valid token
- Verify Keycloak URLs in APIM named values
- Check APIM policy configuration
- Verify token audience matches `apim-client`

### OpenAI integration fails
- Verify OpenAI key in APIM named values
- Check OpenAI deployment name in API call
- Verify OpenAI endpoint URL

## Next Steps

- Review [SETUP.md](./SETUP.md) for detailed configuration
- See [KEYCLOAK-SETUP-KR.md](./KEYCLOAK-SETUP-KR.md) for Korean guide
- Configure HTTPS/TLS for production
- Set up monitoring and alerts

## Clean Up

```bash
azd down --force --purge
```
