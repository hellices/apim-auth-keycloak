"""
AI Foundry + OIDC Integration Sample Application

This sample demonstrates how to:
1. Authenticate with Keycloak using OIDC
2. Use the obtained token to access AI Foundry through APIM
3. Make chat completion requests with proper authentication
"""

import os
import json
import requests
from typing import Optional
from dataclasses import dataclass


@dataclass
class OIDCConfig:
    """OIDC Configuration for Keycloak"""
    authority: str
    client_id: str
    client_secret: str
    # 'openid' is required for OIDC; 'email' and 'profile' provide user info
    scope: str = "openid email profile"
    
    @property
    def token_endpoint(self) -> str:
        return f"{self.authority}/protocol/openid-connect/token"
    
    @property
    def userinfo_endpoint(self) -> str:
        return f"{self.authority}/protocol/openid-connect/userinfo"


@dataclass
class AIFoundryConfig:
    """AI Foundry Configuration through APIM"""
    apim_gateway_url: str
    api_path: str = "/ai-foundry/v1"
    
    @property
    def chat_completions_url(self) -> str:
        return f"{self.apim_gateway_url}{self.api_path}/chat/completions"


class OIDCAuthClient:
    """Client for OIDC authentication with Keycloak"""
    
    def __init__(self, config: OIDCConfig):
        self.config = config
        self._access_token: Optional[str] = None
        self._refresh_token: Optional[str] = None
    
    def authenticate_with_password(self, username: str, password: str) -> dict:
        """
        Authenticate using Resource Owner Password Credentials Grant.
        Note: This is for demo purposes. In production, use Authorization Code Flow.
        """
        payload = {
            "grant_type": "password",
            "client_id": self.config.client_id,
            "client_secret": self.config.client_secret,
            "username": username,
            "password": password,
            "scope": self.config.scope
        }
        
        response = requests.post(
            self.config.token_endpoint,
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code != 200:
            raise Exception(f"Authentication failed: {response.text}")
        
        token_data = response.json()
        self._access_token = token_data.get("access_token")
        self._refresh_token = token_data.get("refresh_token")
        
        return token_data
    
    def authenticate_with_client_credentials(self) -> dict:
        """
        Authenticate using Client Credentials Grant.
        Useful for service-to-service authentication.
        """
        payload = {
            "grant_type": "client_credentials",
            "client_id": self.config.client_id,
            "client_secret": self.config.client_secret,
            "scope": self.config.scope
        }
        
        response = requests.post(
            self.config.token_endpoint,
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code != 200:
            raise Exception(f"Authentication failed: {response.text}")
        
        token_data = response.json()
        self._access_token = token_data.get("access_token")
        
        return token_data
    
    def refresh_access_token(self) -> dict:
        """Refresh the access token using the refresh token"""
        if not self._refresh_token:
            raise Exception("No refresh token available")
        
        payload = {
            "grant_type": "refresh_token",
            "client_id": self.config.client_id,
            "client_secret": self.config.client_secret,
            "refresh_token": self._refresh_token
        }
        
        response = requests.post(
            self.config.token_endpoint,
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code != 200:
            raise Exception(f"Token refresh failed: {response.text}")
        
        token_data = response.json()
        self._access_token = token_data.get("access_token")
        self._refresh_token = token_data.get("refresh_token")
        
        return token_data
    
    def get_user_info(self) -> dict:
        """Get user information from the OIDC provider"""
        if not self._access_token:
            raise Exception("Not authenticated")
        
        response = requests.get(
            self.config.userinfo_endpoint,
            headers={"Authorization": f"Bearer {self._access_token}"}
        )
        
        if response.status_code != 200:
            raise Exception(f"Failed to get user info: {response.text}")
        
        return response.json()
    
    @property
    def access_token(self) -> Optional[str]:
        return self._access_token


class AIFoundryClient:
    """Client for AI Foundry API through APIM"""
    
    def __init__(self, config: AIFoundryConfig, auth_client: OIDCAuthClient):
        self.config = config
        self.auth_client = auth_client
    
    def _get_headers(self) -> dict:
        """Get request headers with authentication"""
        if not self.auth_client.access_token:
            raise Exception("Not authenticated. Please authenticate first.")
        
        return {
            "Authorization": f"Bearer {self.auth_client.access_token}",
            "Content-Type": "application/json"
        }
    
    def chat_completion(
        self,
        messages: list,
        model: str = "gpt-4",
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> dict:
        """
        Send a chat completion request to AI Foundry through APIM.
        
        Args:
            messages: List of message objects with 'role' and 'content'
            model: The model to use for completion
            temperature: Sampling temperature (0-2)
            max_tokens: Maximum tokens in the response
        
        Returns:
            The API response as a dictionary
        """
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        
        response = requests.post(
            self.config.chat_completions_url,
            json=payload,
            headers=self._get_headers()
        )
        
        if response.status_code == 401:
            # Try to refresh token and retry
            try:
                self.auth_client.refresh_access_token()
                response = requests.post(
                    self.config.chat_completions_url,
                    json=payload,
                    headers=self._get_headers()
                )
            except Exception:
                raise Exception("Failed to refresh authentication token. Please re-authenticate.")
        
        if response.status_code != 200:
            raise Exception(f"AI Foundry request failed: {response.text}")
        
        return response.json()
    
    def simple_chat(self, user_message: str, system_message: str = None) -> str:
        """
        Simple chat interface that returns just the assistant's response.
        
        Args:
            user_message: The user's message
            system_message: Optional system message to set context
        
        Returns:
            The assistant's response text
        """
        messages = []
        
        if system_message:
            messages.append({"role": "system", "content": system_message})
        
        messages.append({"role": "user", "content": user_message})
        
        response = self.chat_completion(messages)
        
        choices = response.get("choices", [])
        if choices:
            return choices[0].get("message", {}).get("content", "")
        
        return ""


def main():
    """Example usage of the AI Foundry + OIDC integration"""
    
    # Configuration from environment variables
    oidc_config = OIDCConfig(
        authority=os.getenv("KEYCLOAK_AUTHORITY", "http://localhost:8080/realms/ai-foundry"),
        client_id=os.getenv("KEYCLOAK_CLIENT_ID", "ai-foundry-client"),
        client_secret=os.getenv("KEYCLOAK_CLIENT_SECRET", "your-client-secret-here")
    )
    
    ai_config = AIFoundryConfig(
        apim_gateway_url=os.getenv("APIM_GATEWAY_URL", "https://your-apim.azure-api.net"),
        api_path=os.getenv("AI_FOUNDRY_API_PATH", "/ai-foundry/v1")
    )
    
    # Initialize clients
    auth_client = OIDCAuthClient(oidc_config)
    ai_client = AIFoundryClient(ai_config, auth_client)
    
    # Authenticate
    print("Authenticating with Keycloak...")
    try:
        auth_client.authenticate_with_password(
            username=os.getenv("TEST_USERNAME", "testuser"),
            password=os.getenv("TEST_PASSWORD", "testpassword")
        )
        print("Authentication successful!")
        
        # Get user info
        user_info = auth_client.get_user_info()
        print(f"Logged in as: {user_info.get('email', 'unknown')}")
        
    except Exception as e:
        print(f"Authentication failed: {e}")
        return
    
    # Use AI Foundry
    print("\nSending request to AI Foundry through APIM...")
    try:
        response = ai_client.simple_chat(
            user_message="Hello! What can you help me with today?",
            system_message="You are a helpful AI assistant."
        )
        print(f"AI Response: {response}")
        
    except Exception as e:
        print(f"AI Foundry request failed: {e}")


if __name__ == "__main__":
    main()
