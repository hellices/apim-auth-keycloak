#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== APIM Configuration Helper ===${NC}\n"

# Check if required commands are available
for cmd in az jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

# Get values from azd
echo "Getting Azure resource information..."
if command -v azd &> /dev/null; then
    RESOURCE_GROUP=$(azd env get-value AZURE_RESOURCE_GROUP 2>/dev/null || echo "")
    APIM_NAME=$(azd env get-value APIM_SERVICE_NAME 2>/dev/null || echo "")
    OPENAI_NAME=$(azd env get-value OPENAI_SERVICE_NAME 2>/dev/null || echo "")
else
    echo -e "${YELLOW}Warning: azd not found. Please provide values manually.${NC}"
fi

# Prompt for values if not found
if [ -z "$RESOURCE_GROUP" ]; then
    read -p "Enter Resource Group name: " RESOURCE_GROUP
fi

if [ -z "$APIM_NAME" ]; then
    read -p "Enter APIM Service name: " APIM_NAME
fi

if [ -z "$OPENAI_NAME" ]; then
    read -p "Enter OpenAI Service name: " OPENAI_NAME
fi

echo -e "\n${GREEN}Using:${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "APIM Service: $APIM_NAME"
echo "OpenAI Service: $OPENAI_NAME"

# Get OpenAI key
echo -e "\n${YELLOW}Getting OpenAI API key...${NC}"
OPENAI_KEY=$(az cognitiveservices account keys list \
    --resource-group $RESOURCE_GROUP \
    --name $OPENAI_NAME \
    --query "key1" -o tsv)

if [ -z "$OPENAI_KEY" ]; then
    echo -e "${RED}Error: Could not retrieve OpenAI key${NC}"
    exit 1
fi

echo -e "${GREEN}✓ OpenAI key retrieved${NC}"

# Update APIM named value
echo -e "\n${YELLOW}Updating APIM named value for OpenAI key...${NC}"
az apim nv update \
    --resource-group $RESOURCE_GROUP \
    --service-name $APIM_NAME \
    --named-value-id openai-key \
    --value "$OPENAI_KEY" \
    --secret true

echo -e "${GREEN}✓ APIM configured with OpenAI key${NC}"

# Get Keycloak URLs if available
if [ -f "keycloak-urls.txt" ]; then
    echo -e "\n${YELLOW}Found keycloak-urls.txt. Do you want to update APIM with Keycloak URLs? (y/n)${NC}"
    read -p "> " update_keycloak
    
    if [ "$update_keycloak" = "y" ]; then
        KEYCLOAK_ISSUER=$(grep "Keycloak Issuer URL:" keycloak-urls.txt | cut -d' ' -f4)
        KEYCLOAK_JWKS=$(grep "Keycloak JWKS URL:" keycloak-urls.txt | cut -d' ' -f4)
        
        echo "Updating Keycloak issuer URL..."
        az apim nv update \
            --resource-group $RESOURCE_GROUP \
            --service-name $APIM_NAME \
            --named-value-id keycloak-issuer-url \
            --value "$KEYCLOAK_ISSUER"
        
        echo "Updating Keycloak JWKS URL..."
        az apim nv update \
            --resource-group $RESOURCE_GROUP \
            --service-name $APIM_NAME \
            --named-value-id keycloak-jwks-url \
            --value "$KEYCLOAK_JWKS"
        
        echo -e "${GREEN}✓ APIM configured with Keycloak URLs${NC}"
    fi
else
    echo -e "\n${YELLOW}Note: keycloak-urls.txt not found. Run ./scripts/get-keycloak-urls.sh first.${NC}"
fi

# Get APIM gateway URL
APIM_GATEWAY_URL=$(az apim show \
    --resource-group $RESOURCE_GROUP \
    --name $APIM_NAME \
    --query "gatewayUrl" -o tsv)

echo -e "\n${GREEN}=== Configuration Complete ===${NC}"
echo "APIM Gateway URL: $APIM_GATEWAY_URL"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Import the OpenAPI spec to APIM (see SETUP.md section 4.3)"
echo "2. Apply the JWT validation policy (see SETUP.md section 4.4)"
echo "3. Test the integration (see SETUP.md Part 5)"
