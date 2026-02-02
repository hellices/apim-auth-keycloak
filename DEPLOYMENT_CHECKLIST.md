# Deployment Checklist

Use this checklist to ensure successful deployment of the Keycloak-APIM-Azure OpenAI integration.

## Pre-Deployment

- [ ] Azure subscription with required permissions
- [ ] Azure CLI installed (`az --version`)
- [ ] Azure Developer CLI installed (`azd version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] curl and jq installed (for testing)
- [ ] Sufficient Azure quota:
  - [ ] AKS nodes (3x Standard_D2s_v3)
  - [ ] Public IP addresses (1 for Keycloak LoadBalancer)
  - [ ] Azure OpenAI service available in region

## Phase 1: Infrastructure Deployment (10 minutes)

- [ ] Login to Azure: `az login`
- [ ] Login to azd: `azd auth login`
- [ ] Create environment: `azd env new <env-name>`
- [ ] Set location: `azd env set AZURE_LOCATION "koreacentral"`
- [ ] Deploy infrastructure: `azd up`
- [ ] Wait for deployment to complete
- [ ] Save output values:
  ```bash
  export RESOURCE_GROUP=$(azd env get-value AZURE_RESOURCE_GROUP)
  export AKS_NAME=$(azd env get-value AKS_CLUSTER_NAME)
  export APIM_NAME=$(azd env get-value APIM_SERVICE_NAME)
  export OPENAI_NAME=$(azd env get-value OPENAI_SERVICE_NAME)
  ```

## Phase 2: Keycloak Deployment (5 minutes)

- [ ] Get AKS credentials: `az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME`
- [ ] Verify cluster access: `kubectl get nodes`
- [ ] Deploy Keycloak: `kubectl apply -f kubernetes/keycloak-deployment.yaml`
- [ ] Wait for deployment: `kubectl wait --for=condition=available --timeout=600s deployment/keycloak -n keycloak`
- [ ] Check pod status: `kubectl get pods -n keycloak`
- [ ] Get external IP: `./scripts/get-keycloak-urls.sh`
- [ ] Wait for LoadBalancer IP to be assigned (may take 5 minutes)
- [ ] Verify Keycloak is accessible in browser

## Phase 3: Keycloak Configuration (10 minutes)

- [ ] Access Keycloak Admin Console: `http://<EXTERNAL-IP>:8080`
- [ ] Login with admin/admin
- [ ] Create realm:
  - [ ] Name: `apim`
  - [ ] Enabled: ON
- [ ] Create client:
  - [ ] Client ID: `apim-client`
  - [ ] Client authentication: ON
  - [ ] Standard flow: ENABLED
  - [ ] Direct access grants: ENABLED
  - [ ] Valid redirect URIs: `https://oauth.pstmn.io/v1/callback`, `http://localhost:*`
- [ ] Copy client secret from Credentials tab
- [ ] Create test user:
  - [ ] Username: `testuser`
  - [ ] Email: `testuser@example.com`
  - [ ] Email verified: ON
  - [ ] Set password: `Test123!` (Temporary: OFF)
- [ ] (Optional) Create realm role `api-user` and assign to user

## Phase 4: APIM Configuration (5 minutes)

### 4.1 Update APIM Named Values

- [ ] Run configuration script: `./scripts/configure-apim.sh`
  - [ ] Verifies Keycloak URLs are updated
  - [ ] Updates OpenAI API key
- [ ] Or manually update:
  ```bash
  # Get Keycloak URLs
  export KEYCLOAK_IP=$(kubectl get svc keycloak -n keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  export KEYCLOAK_ISSUER="http://$KEYCLOAK_IP:8080/realms/apim"
  
  # Update APIM
  az apim nv update --resource-group $RESOURCE_GROUP --service-name $APIM_NAME \
    --named-value-id keycloak-issuer-url --value "$KEYCLOAK_ISSUER"
  
  az apim nv update --resource-group $RESOURCE_GROUP --service-name $APIM_NAME \
    --named-value-id keycloak-jwks-url --value "$KEYCLOAK_ISSUER/protocol/openid-connect/certs"
  
  # Update OpenAI key
  export OPENAI_KEY=$(az cognitiveservices account keys list \
    --resource-group $RESOURCE_GROUP --name $OPENAI_NAME --query "key1" -o tsv)
  az apim nv update --resource-group $RESOURCE_GROUP --service-name $APIM_NAME \
    --named-value-id openai-key --value "$OPENAI_KEY" --secret true
  ```

### 4.2 Import and Configure API

In Azure Portal:
- [ ] Navigate to APIM service
- [ ] Go to APIs → "Add API" → "OpenAPI"
- [ ] Select "Full" mode
- [ ] Upload `apim-policies/openai-api-spec.json`
- [ ] Set API URL suffix: `openai`
- [ ] Create API
- [ ] Select "All operations"
- [ ] Open Policy code editor (</> icon)
- [ ] Copy content from `apim-policies/openai-api-policy.xml`
- [ ] Paste and save

## Phase 5: Testing (2 minutes)

### 5.1 Automated Test

- [ ] Run test script: `./scripts/test-integration.sh`
- [ ] Verify all tests pass:
  - [ ] Token obtained from Keycloak
  - [ ] Request without token returns 401
  - [ ] Request with token returns 200
  - [ ] OpenAI response received

### 5.2 Manual Test

- [ ] Get Keycloak client secret
- [ ] Get access token:
  ```bash
  curl -X POST "http://<KEYCLOAK-IP>:8080/realms/apim/protocol/openid-connect/token" \
    -d "client_id=apim-client" \
    -d "client_secret=<SECRET>" \
    -d "grant_type=password" \
    -d "username=testuser" \
    -d "password=Test123!" | jq -r '.access_token'
  ```
- [ ] Test API without token (expect 401):
  ```bash
  curl -X POST "<APIM-URL>/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user","content":"test"}]}'
  ```
- [ ] Test API with token (expect 200):
  ```bash
  curl -X POST "<APIM-URL>/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
    -H "Authorization: Bearer <TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user","content":"Hello!"}],"max_tokens":50}'
  ```

## Post-Deployment Verification

- [ ] Keycloak is accessible and responsive
- [ ] Keycloak admin console works
- [ ] Test user can authenticate
- [ ] APIM gateway is accessible
- [ ] APIM rejects requests without token (401)
- [ ] APIM accepts requests with valid token (200)
- [ ] OpenAI integration works (receives AI responses)
- [ ] Rate limiting is working (test by exceeding limit)

## Monitoring Setup (Optional)

- [ ] Enable APIM diagnostic logs
- [ ] Configure Log Analytics workspace
- [ ] Set up Azure Monitor alerts for:
  - [ ] APIM 401 errors (authentication failures)
  - [ ] APIM 429 errors (rate limit exceeded)
  - [ ] APIM 500 errors (backend failures)
  - [ ] Keycloak pod crashes
- [ ] Configure Keycloak logging level if needed

## Documentation Review

- [ ] Team has access to documentation
- [ ] Review [SETUP.md](./SETUP.md) for detailed instructions
- [ ] Review [ARCHITECTURE.md](./ARCHITECTURE.md) for system design
- [ ] Review [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues
- [ ] Review [KEYCLOAK-SETUP-KR.md](./KEYCLOAK-SETUP-KR.md) for Korean guide

## Security Hardening (Production)

- [ ] Change Keycloak admin password from default
- [ ] Change database passwords
- [ ] Configure HTTPS/TLS for Keycloak
- [ ] Use Azure Key Vault for secrets
- [ ] Configure network security groups
- [ ] Enable Azure Private Link for APIM
- [ ] Enable Azure Private Link for OpenAI
- [ ] Configure custom domain for Keycloak
- [ ] Set up certificate management
- [ ] Review and adjust token lifetimes
- [ ] Configure session timeouts
- [ ] Enable audit logging
- [ ] Regular security updates for Keycloak

## Backup and Disaster Recovery

- [ ] Export Keycloak realm configuration
- [ ] Backup PostgreSQL database
- [ ] Document recovery procedures
- [ ] Test restoration process

## Success Criteria

✅ All infrastructure deployed successfully  
✅ Keycloak accessible and configured  
✅ APIM policies active and validating tokens  
✅ End-to-end authentication flow working  
✅ OpenAI API accessible through APIM  
✅ Rate limiting enforced  
✅ Documentation complete and accessible  
✅ Team trained on maintenance procedures  

## Rollback Plan

If deployment fails:
1. Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. Review logs: `kubectl logs -n keycloak`, APIM diagnostics
3. If needed, rollback: `azd down --force --purge`
4. Fix issues and redeploy: `azd up`

## Next Steps

After successful deployment:
1. Configure additional OpenAI models/deployments
2. Add more users and roles in Keycloak
3. Customize APIM policies for specific needs
4. Set up CI/CD for configuration updates
5. Plan for scaling (AKS nodes, APIM SKU)
6. Schedule regular security reviews

## Notes

- Total deployment time: ~30 minutes
- Keycloak initial startup: ~5 minutes
- LoadBalancer provisioning: ~5 minutes
- APIM policy updates: Immediate
- Keep this checklist for future deployments
