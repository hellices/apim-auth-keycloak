# Troubleshooting Guide

Common issues and their solutions for the Keycloak-APIM-Azure OpenAI integration.

## Table of Contents

1. [Infrastructure Deployment Issues](#infrastructure-deployment-issues)
2. [Keycloak Issues](#keycloak-issues)
3. [APIM Configuration Issues](#apim-configuration-issues)
4. [Authentication Issues](#authentication-issues)
5. [API Call Issues](#api-call-issues)
6. [Network Issues](#network-issues)

---

## Infrastructure Deployment Issues

### Issue: `azd up` fails with permission error

**Symptoms**:
```
ERROR: Authorization failed
```

**Solutions**:
1. Verify you're logged in: `az login` and `azd auth login`
2. Check subscription permissions: `az account show`
3. Ensure you have Contributor role on the subscription

### Issue: Resource name conflicts

**Symptoms**:
```
ERROR: The resource name already exists
```

**Solutions**:
1. Use a different environment name: `azd env new <different-name>`
2. Delete existing resources: `azd down --force --purge`
3. Change resource names in `infra/main.parameters.json`

### Issue: OpenAI service not available in region

**Symptoms**:
```
ERROR: The subscription is not registered for resource type 'Microsoft.CognitiveServices/accounts'
```

**Solutions**:
1. Register the provider: `az provider register --namespace Microsoft.CognitiveServices`
2. Wait a few minutes and retry
3. Use a different region where OpenAI is available (e.g., eastus, westeurope)

---

## Keycloak Issues

### Issue: Keycloak pod not starting

**Symptoms**:
```bash
$ kubectl get pods -n keycloak
NAME                        READY   STATUS             RESTARTS   AGE
keycloak-xxx                0/1     CrashLoopBackOff   5          5m
```

**Diagnosis**:
```bash
kubectl logs deployment/keycloak -n keycloak
kubectl describe pod <pod-name> -n keycloak
```

**Common Causes & Solutions**:

1. **Database connection issues**:
   - Check PostgreSQL pod is running: `kubectl get pods -n keycloak`
   - Verify database credentials in secret: `kubectl get secret keycloak-db-secret -n keycloak -o yaml`

2. **Memory/CPU limits**:
   - Check resource constraints: `kubectl describe pod <pod-name> -n keycloak`
   - Increase limits in `kubernetes/keycloak-deployment.yaml` if needed

3. **Image pull issues**:
   - Verify image name: `quay.io/keycloak/keycloak:23.0`
   - Check network connectivity from AKS

### Issue: Keycloak LoadBalancer stuck in "Pending"

**Symptoms**:
```bash
$ kubectl get svc keycloak -n keycloak
NAME       TYPE           EXTERNAL-IP   PORT(S)
keycloak   LoadBalancer   <pending>     8080:30080/TCP
```

**Solutions**:
1. Wait 5-10 minutes for Azure to provision the load balancer
2. Check AKS subnet has available IPs
3. Check Azure subscription quota for public IPs:
   ```bash
   az network public-ip list --resource-group <rg> --output table
   ```
4. Check AKS cluster status:
   ```bash
   az aks show --resource-group <rg> --name <aks-name> --query provisioningState
   ```

### Issue: Cannot access Keycloak admin console

**Symptoms**: Browser timeout when accessing `http://<EXTERNAL-IP>:8080`

**Solutions**:
1. Verify external IP is assigned: `kubectl get svc keycloak -n keycloak`
2. Check Keycloak pod is running: `kubectl get pods -n keycloak`
3. Test connectivity from your machine:
   ```bash
   curl -I http://<EXTERNAL-IP>:8080
   ```
4. Check if your network blocks port 8080
5. Try port forwarding as alternative:
   ```bash
   kubectl port-forward svc/keycloak 8080:8080 -n keycloak
   # Then access http://localhost:8080
   ```

---

## APIM Configuration Issues

### Issue: Cannot update APIM named values

**Symptoms**:
```
ERROR: The service is currently updating. Please retry later.
```

**Solutions**:
1. Wait 10-15 minutes for APIM to finish provisioning
2. Check APIM status in Azure Portal
3. Retry the command

### Issue: APIM policy validation fails

**Symptoms**: Error when saving policy in Azure Portal

**Solutions**:
1. Check XML syntax in policy file
2. Verify named values exist: `{{keycloak-issuer-url}}`, `{{openai-key}}`
3. Ensure policy elements are in correct order (inbound → backend → outbound)
4. Test with minimal policy first, then add features

### Issue: OpenAI API import fails

**Symptoms**: Cannot import `openai-api-spec.json`

**Solutions**:
1. Validate JSON syntax: `jq . apim-policies/openai-api-spec.json`
2. Use "Full" import mode, not "Link"
3. Try importing via Azure CLI:
   ```bash
   az apim api import \
     --resource-group <rg> \
     --service-name <apim-name> \
     --path openai \
     --specification-path apim-policies/openai-api-spec.json \
     --specification-format OpenApi
   ```

---

## Authentication Issues

### Issue: Cannot get token from Keycloak

**Symptoms**:
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid user credentials"
}
```

**Solutions**:
1. Verify username and password are correct
2. Check user exists in Keycloak admin console
3. Ensure password is not set as "Temporary"
4. Verify client ID and client secret are correct
5. Check realm name is correct (`apim`)

### Issue: Token request returns "unauthorized_client"

**Symptoms**:
```json
{
  "error": "unauthorized_client",
  "error_description": "Invalid client or Invalid client credentials"
}
```

**Solutions**:
1. Verify client secret is correct
2. Check "Client authentication" is enabled in client settings
3. Ensure "Direct access grants" flow is enabled
4. Verify client ID matches exactly

### Issue: Token validation fails in APIM

**Symptoms**: API returns 401 even with valid token

**Diagnosis**:
1. Enable APIM trace:
   - Add header: `Ocp-Apim-Trace: true`
   - Add subscription key header
   - Check trace output for detailed error

2. Decode JWT token at [jwt.io](https://jwt.io) and verify:
   - `iss` (issuer) matches Keycloak realm URL
   - `aud` (audience) matches `apim-client`
   - `exp` (expiration) is in the future
   - Token signature is valid

**Common Solutions**:

1. **Issuer mismatch**:
   ```bash
   # Update APIM named value
   az apim nv update \
     --resource-group <rg> \
     --service-name <apim> \
     --named-value-id keycloak-issuer-url \
     --value "http://<CORRECT-IP>:8080/realms/apim"
   ```

2. **Audience mismatch**:
   - Check APIM policy has correct audience: `<audience>apim-client</audience>`
   - Verify Keycloak client ID is `apim-client`

3. **JWKS URL not accessible**:
   - Test from your machine: `curl http://<KEYCLOAK-IP>:8080/realms/apim/protocol/openid-connect/certs`
   - Ensure APIM can reach Keycloak (network connectivity)

4. **Token expired**:
   - Get a new token
   - Consider increasing token lifespan in Keycloak (Realm Settings → Tokens)

---

## API Call Issues

### Issue: OpenAI request returns 401

**Symptoms**: Valid JWT but OpenAI call fails

**Solutions**:
1. Verify OpenAI API key in APIM:
   ```bash
   az apim nv show \
     --resource-group <rg> \
     --service-name <apim> \
     --named-value-id openai-key
   ```
2. Test OpenAI key directly:
   ```bash
   curl https://<openai-name>.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview \
     -H "api-key: <key>" \
     -H "Content-Type: application/json" \
     -d '{"messages":[{"role":"user","content":"test"}]}'
   ```
3. Regenerate OpenAI key if needed and update APIM

### Issue: OpenAI request returns 404

**Symptoms**:
```json
{
  "error": {
    "code": "DeploymentNotFound",
    "message": "The API deployment for this resource does not exist."
  }
}
```

**Solutions**:
1. Verify deployment name in OpenAI:
   ```bash
   az cognitiveservices account deployment list \
     --resource-group <rg> \
     --name <openai-name>
   ```
2. Update API call to use correct deployment name
3. Deploy missing model if needed:
   ```bash
   az cognitiveservices account deployment create \
     --resource-group <rg> \
     --name <openai-name> \
     --deployment-name gpt-4 \
     --model-name gpt-4 \
     --model-version "0613" \
     --model-format OpenAI \
     --sku-capacity 10 \
     --sku-name Standard
   ```

### Issue: Rate limiting errors

**Symptoms**:
```json
{
  "statusCode": 429,
  "message": "Rate limit is exceeded. Try again in X seconds."
}
```

**Solutions**:
1. Wait for rate limit window to reset
2. Adjust rate limit in APIM policy:
   ```xml
   <rate-limit-by-key calls="200" renewal-period="60" ... />
   ```
3. Implement retry logic in client application
4. Use different users to distribute load

---

## Network Issues

### Issue: APIM cannot reach Keycloak

**Symptoms**: JWT validation fails, JWKS endpoint unreachable

**Diagnosis**:
```bash
# From APIM, test connectivity (using Kudu or Azure Portal console)
curl http://<KEYCLOAK-IP>:8080/realms/apim/.well-known/openid-configuration
```

**Solutions**:
1. Verify Keycloak LoadBalancer has external IP
2. Check network security groups (NSG) allow traffic
3. Ensure Keycloak service type is LoadBalancer, not ClusterIP
4. Consider using Azure Application Gateway or Front Door for production

### Issue: Client cannot reach APIM

**Symptoms**: Timeout when calling APIM gateway URL

**Solutions**:
1. Verify APIM gateway URL: `az apim show --name <apim> --resource-group <rg> --query gatewayUrl`
2. Check APIM is provisioned and running (not in update state)
3. Test connectivity: `curl <APIM-GATEWAY-URL>`
4. Check DNS resolution
5. Verify no firewall blocking HTTPS (443)

---

## Debugging Commands

### Check all components status

```bash
# Infrastructure
az group show --name <rg> --query provisioningState

# AKS
az aks show --resource-group <rg> --name <aks> --query provisioningState

# APIM
az apim show --resource-group <rg> --name <apim> --query provisioningState

# OpenAI
az cognitiveservices account show --resource-group <rg> --name <openai> --query provisioningState

# Keycloak on AKS
kubectl get all -n keycloak
kubectl logs deployment/keycloak -n keycloak --tail=50
kubectl describe pod <pod-name> -n keycloak
```

### Get configuration values

```bash
# From azd
azd env get-values

# Keycloak URL
kubectl get svc keycloak -n keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# APIM Gateway URL
az apim show --resource-group <rg> --name <apim> --query gatewayUrl -o tsv

# OpenAI Endpoint
az cognitiveservices account show --resource-group <rg> --name <openai> --query properties.endpoint -o tsv
```

### Test token flow

```bash
# 1. Get token
TOKEN=$(curl -s -X POST "http://<KEYCLOAK-IP>:8080/realms/apim/protocol/openid-connect/token" \
  -d "client_id=apim-client" \
  -d "client_secret=<SECRET>" \
  -d "grant_type=password" \
  -d "username=testuser" \
  -d "password=Test123!" \
  | jq -r '.access_token')

# 2. Decode token
echo $TOKEN | cut -d. -f2 | base64 -d | jq .

# 3. Test API with token
curl -X POST "<APIM-URL>/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}'
```

---

## Getting Help

If issues persist:

1. Check [SETUP.md](./SETUP.md) for detailed setup instructions
2. Review [ARCHITECTURE.md](./ARCHITECTURE.md) for system design
3. Enable verbose logging:
   - APIM: Enable diagnostic logs
   - Keycloak: Set log level to DEBUG
   - AKS: Check container logs
4. Open an issue on GitHub with:
   - Error messages
   - Logs
   - Configuration (redact secrets)
   - Steps to reproduce

## Common Error Messages Reference

| Error | Component | Likely Cause |
|-------|-----------|--------------|
| `invalid_grant` | Keycloak | Wrong credentials |
| `unauthorized_client` | Keycloak | Wrong client secret |
| `401 Unauthorized` | APIM | JWT validation failed |
| `404 Not Found` | APIM/OpenAI | Wrong deployment name |
| `429 Too Many Requests` | APIM | Rate limit exceeded |
| `500 Internal Server Error` | Any | Check logs for details |
| `CrashLoopBackOff` | Kubernetes | Pod failing to start |
| `ImagePullBackOff` | Kubernetes | Cannot pull container image |
