# Architecture: AI Foundry + OIDC Integration

## Overview

This document describes the architecture for integrating AI Foundry with OIDC authentication (Keycloak) through Azure API Management (APIM).

## System Components

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Client App    │────▶│    Keycloak     │     │      APIM       │────▶│   AI Foundry    │
│  (Python/JS)    │     │  (OIDC Provider)│     │  (API Gateway)  │     │    (Azure)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
        │                        │                       │                       │
        │  1. Login Request      │                       │                       │
        │───────────────────────▶│                       │                       │
        │                        │                       │                       │
        │  2. JWT Token          │                       │                       │
        │◀───────────────────────│                       │                       │
        │                        │                       │                       │
        │  3. API Request + Bearer Token                 │                       │
        │───────────────────────────────────────────────▶│                       │
        │                        │                       │                       │
        │                        │  4. Validate Token    │                       │
        │                        │◀──────────────────────│                       │
        │                        │                       │                       │
        │                        │  5. Token Valid       │                       │
        │                        │──────────────────────▶│                       │
        │                        │                       │                       │
        │                        │                       │  6. Forward Request   │
        │                        │                       │──────────────────────▶│
        │                        │                       │                       │
        │                        │                       │  7. AI Response       │
        │                        │                       │◀──────────────────────│
        │                        │                       │                       │
        │  8. API Response + Usage Data                  │                       │
        │◀───────────────────────────────────────────────│                       │
        │                        │                       │                       │
        │                        │                       │  9. Log to Event Hub  │
        │                        │                       │──────┐                │
        │                        │                       │      │                │
        │                        │                       │      ▼                │
        │                        │                       │ ┌─────────────────┐   │
        │                        │                       │ │   Event Hub     │   │
        │                        │                       │ │  (Logging)      │   │
        │                        │                       │ └─────────────────┘   │
```

## Authentication Flow

### 1. User Authentication (OIDC)

1. User initiates login from client application
2. Client redirects to Keycloak login page (Authorization Code Flow) or sends credentials directly (Password Grant for testing)
3. User authenticates with Keycloak
4. Keycloak issues JWT tokens (access_token, refresh_token, id_token)
5. Client stores tokens securely

### 2. API Request Flow

1. Client makes API request to APIM with Bearer token
2. APIM validates JWT token against Keycloak's OIDC configuration
3. APIM extracts user information from token
4. APIM adds user context headers to request
5. APIM logs authentication event
6. Request is forwarded to AI Foundry
7. AI Foundry processes request and returns response
8. APIM logs prompt and usage data
9. Response is returned to client

## Data Logging

### Authentication Events

```json
{
  "event": "user_authentication",
  "userId": "user-uuid",
  "userEmail": "user@example.com",
  "timestamp": "2024-01-15T10:30:00Z",
  "operationId": "request-uuid",
  "apiPath": "/ai-foundry/v1/chat/completions",
  "method": "POST"
}
```

### Prompt Usage Events

```json
{
  "eventType": "ai_prompt_request",
  "userId": "user-uuid",
  "userEmail": "user@example.com",
  "timestamp": "2024-01-15T10:30:00Z",
  "operationId": "request-uuid",
  "prompt": {
    "lastUserPrompt": "What is machine learning?",
    "totalMessages": 3,
    "userMessageCount": 2,
    "model": "gpt-4",
    "temperature": 0.7,
    "maxTokens": 1000
  }
}
```

### Response Usage Events

```json
{
  "eventType": "ai_prompt_response",
  "userId": "user-uuid",
  "timestamp": "2024-01-15T10:30:01Z",
  "operationId": "request-uuid",
  "usage": {
    "promptTokens": 150,
    "completionTokens": 250,
    "totalTokens": 400,
    "model": "gpt-4",
    "finishReason": "stop"
  },
  "responseTimeMs": 1250,
  "statusCode": 200
}
```

## Security Considerations

### Token Security

- Tokens are validated against Keycloak's OIDC configuration
- Token expiration is enforced
- Token issuer and audience are verified
- Required claims are validated

### Data Privacy

- Only partial prompt content is logged (first 500 characters)
- Sensitive data should be masked in production
- Consider data retention policies
- Implement access controls on logged data

### Network Security

- Use HTTPS for all communications
- Implement rate limiting in APIM
- Consider IP filtering
- Use private endpoints where possible

## Monitoring & Analytics

### Available Metrics

- User login frequency
- API calls per user
- Token usage per user
- Model usage distribution
- Response time percentiles
- Error rates by user/endpoint

### Dashboard Options

1. **Azure Monitor Workbooks**: Native Azure monitoring
2. **Power BI**: Business intelligence dashboards
3. **Custom Analytics**: Using Event Hub data with custom processing

## Deployment Considerations

### Production Checklist

- [ ] Configure proper client secrets in Key Vault
- [ ] Set up Event Hub with appropriate partitioning
- [ ] Configure Application Insights sampling
- [ ] Implement proper error handling
- [ ] Set up alerting for authentication failures
- [ ] Configure backup and disaster recovery
- [ ] Implement rate limiting policies
- [ ] Enable diagnostic logging

### Scaling Considerations

- Event Hub partitioning for high throughput
- APIM scaling units based on expected load
- Keycloak clustering for high availability
