#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Keycloak Configuration Helper ===${NC}\n"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if Keycloak is running
echo "Checking Keycloak deployment status..."
if ! kubectl get deployment keycloak -n keycloak &> /dev/null; then
    echo -e "${RED}Error: Keycloak deployment not found${NC}"
    echo "Please deploy Keycloak first: kubectl apply -f kubernetes/keycloak-deployment.yaml"
    exit 1
fi

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/keycloak -n keycloak || {
    echo -e "${RED}Error: Keycloak did not become ready${NC}"
    exit 1
}

# Get Keycloak external IP
echo -e "\n${GREEN}Getting Keycloak URL...${NC}"
KEYCLOAK_IP=$(kubectl get svc keycloak -n keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$KEYCLOAK_IP" ]; then
    echo -e "${RED}Error: Could not get Keycloak external IP${NC}"
    echo "The service might still be provisioning. Please wait and try again."
    exit 1
fi

KEYCLOAK_URL="http://${KEYCLOAK_IP}:8080"
echo -e "${GREEN}Keycloak URL: ${KEYCLOAK_URL}${NC}"

# Export URLs for APIM configuration
KEYCLOAK_ISSUER="${KEYCLOAK_URL}/realms/apim"
KEYCLOAK_JWKS="${KEYCLOAK_URL}/realms/apim/protocol/openid-connect/certs"

echo -e "\n${GREEN}=== Keycloak Configuration URLs ===${NC}"
echo -e "Admin Console: ${KEYCLOAK_URL}"
echo -e "Realm: apim"
echo -e "Issuer URL: ${KEYCLOAK_ISSUER}"
echo -e "JWKS URL: ${KEYCLOAK_JWKS}"

echo -e "\n${YELLOW}=== Next Steps ===${NC}"
echo "1. Access Keycloak Admin Console: ${KEYCLOAK_URL}"
echo "   - Username: admin"
echo "   - Password: admin"
echo ""
echo "2. Create realm 'apim' and client 'apim-client' as described in SETUP.md"
echo ""
echo "3. Update APIM with Keycloak URLs:"
echo ""
echo "   export RESOURCE_GROUP=<your-resource-group>"
echo "   export APIM_NAME=<your-apim-name>"
echo ""
echo "   az apim nv update \\"
echo "     --resource-group \$RESOURCE_GROUP \\"
echo "     --service-name \$APIM_NAME \\"
echo "     --named-value-id keycloak-issuer-url \\"
echo "     --value \"${KEYCLOAK_ISSUER}\""
echo ""
echo "   az apim nv update \\"
echo "     --resource-group \$RESOURCE_GROUP \\"
echo "     --service-name \$APIM_NAME \\"
echo "     --named-value-id keycloak-jwks-url \\"
echo "     --value \"${KEYCLOAK_JWKS}\""
echo ""

# Save to file
cat > keycloak-urls.txt <<EOF
Keycloak Admin Console: ${KEYCLOAK_URL}
Keycloak Issuer URL: ${KEYCLOAK_ISSUER}
Keycloak JWKS URL: ${KEYCLOAK_JWKS}

Admin Credentials:
Username: admin
Password: admin
EOF

echo -e "${GREEN}URLs saved to keycloak-urls.txt${NC}"
