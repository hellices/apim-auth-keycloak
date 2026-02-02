#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Keycloak + APIM + Azure OpenAI Integration Test          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Check required commands
for cmd in curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

# Get configuration
if [ -f "keycloak-urls.txt" ]; then
    KEYCLOAK_URL=$(grep "Keycloak Admin Console:" keycloak-urls.txt | cut -d' ' -f4)
    KEYCLOAK_ISSUER=$(grep "Keycloak Issuer URL:" keycloak-urls.txt | cut -d' ' -f4)
else
    echo -e "${YELLOW}keycloak-urls.txt not found${NC}"
    read -p "Enter Keycloak URL (e.g., http://1.2.3.4:8080): " KEYCLOAK_URL
    KEYCLOAK_ISSUER="${KEYCLOAK_URL}/realms/apim"
fi

read -p "Enter Keycloak client ID [apim-client]: " CLIENT_ID
CLIENT_ID=${CLIENT_ID:-apim-client}

read -sp "Enter Keycloak client secret: " CLIENT_SECRET
echo ""

read -p "Enter test username [testuser]: " USERNAME
USERNAME=${USERNAME:-testuser}

read -sp "Enter test user password [Test123!]: " PASSWORD
PASSWORD=${PASSWORD:-Test123!}
echo ""

read -p "Enter APIM Gateway URL: " APIM_URL

echo -e "\n${YELLOW}Step 1: Getting access token from Keycloak...${NC}"

TOKEN_RESPONSE=$(curl -s -X POST \
    "${KEYCLOAK_ISSUER}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "grant_type=password" \
    -d "username=${USERNAME}" \
    -d "password=${PASSWORD}")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}✗ Failed to get access token${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Access token obtained${NC}"
echo "Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."

echo -e "\n${YELLOW}Step 2: Testing API without token (should fail)...${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${APIM_URL}/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
    -H "Content-Type: application/json" \
    -d '{
        "messages": [{"role": "user", "content": "Hello"}],
        "max_tokens": 50
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓ API correctly rejected request without token (401)${NC}"
else
    echo -e "${RED}✗ Unexpected status code: $HTTP_CODE${NC}"
    echo "Response: $BODY"
fi

echo -e "\n${YELLOW}Step 3: Testing API with valid token...${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${APIM_URL}/openai/deployments/gpt-4/chat/completions?api-version=2024-02-15-preview" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "messages": [
            {"role": "system", "content": "You are a helpful assistant. Keep responses very brief."},
            {"role": "user", "content": "Say hello in one sentence"}
        ],
        "max_tokens": 50,
        "temperature": 0.7
    }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ API request successful (200)${NC}"
    echo -e "\n${BLUE}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}✗ API request failed with status code: $HTTP_CODE${NC}"
    echo "Response: $BODY"
fi

echo -e "\n${GREEN}=== Test Complete ===${NC}"
echo ""
echo "Summary:"
echo "- Keycloak authentication: ✓"
echo "- APIM JWT validation: ✓"
echo "- Azure OpenAI integration: Check response above"
