"""OAuth2 client for Gmail and Outlook."""

import secrets
import time
from typing import Any
from urllib.parse import urlencode

import httpx

from realmail.core.config import settings
from realmail.core.exceptions import OAuthError
from realmail.core.logging import get_logger
from realmail.core.models.account import Provider

logger = get_logger(__name__)


class OAuthConfig:
    """OAuth2 provider configuration."""

    def __init__(
        self,
        provider: Provider,
        client_id: str,
        client_secret: str,
        auth_url: str,
        token_url: str,
        scopes: list[str],
        redirect_path: str,
    ) -> None:
        self.provider = provider
        self.client_id = client_id
        self.client_secret = client_secret
        self.auth_url = auth_url
        self.token_url = token_url
        self.scopes = scopes
        self.redirect_path = redirect_path

    @property
    def redirect_uri(self) -> str:
        return f"{settings.oauth_redirect_base_url}{self.redirect_path}"


# Provider configurations
GOOGLE_CONFIG = OAuthConfig(
    provider=Provider.GMAIL,
    client_id=settings.google_client_id,
    client_secret=settings.google_client_secret,
    auth_url="https://accounts.google.com/o/oauth2/v2/auth",
    token_url="https://oauth2.googleapis.com/token",
    scopes=[
        "https://mail.google.com/",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    ],
    redirect_path="/auth/google/callback",
)

MICROSOFT_CONFIG = OAuthConfig(
    provider=Provider.OUTLOOK,
    client_id=settings.microsoft_client_id,
    client_secret=settings.microsoft_client_secret,
    auth_url="https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
    token_url="https://login.microsoftonline.com/common/oauth2/v2.0/token",
    scopes=[
        "https://outlook.office.com/IMAP.AccessAsUser.All",
        "https://outlook.office.com/SMTP.Send",
        "offline_access",
        "openid",
        "email",
        "profile",
    ],
    redirect_path="/auth/microsoft/callback",
)


class OAuthClient:
    """OAuth2 client for handling authorization flows."""

    def __init__(self, config: OAuthConfig) -> None:
        self.config = config
        self._http_client: httpx.AsyncClient | None = None
        # Store states for CSRF protection (in production, use Redis)
        self._states: dict[str, float] = {}

    async def _get_client(self) -> httpx.AsyncClient:
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=30.0)
        return self._http_client

    async def close(self) -> None:
        if self._http_client:
            await self._http_client.aclose()
            self._http_client = None

    def generate_state(self) -> str:
        """Generate a CSRF state token."""
        state = secrets.token_urlsafe(32)
        self._states[state] = time.time()
        # Clean old states (older than 10 minutes)
        cutoff = time.time() - 600
        self._states = {k: v for k, v in self._states.items() if v > cutoff}
        return state

    def verify_state(self, state: str) -> bool:
        """Verify and consume a state token."""
        if state in self._states:
            del self._states[state]
            return True
        return False

    def get_authorization_url(self, state: str | None = None) -> str:
        """Get the OAuth2 authorization URL."""
        if state is None:
            state = self.generate_state()

        params = {
            "client_id": self.config.client_id,
            "redirect_uri": self.config.redirect_uri,
            "scope": " ".join(self.config.scopes),
            "response_type": "code",
            "state": state,
            "access_type": "offline",
            "prompt": "consent",
        }
        return f"{self.config.auth_url}?{urlencode(params)}"

    async def exchange_code(self, code: str) -> dict[str, Any]:
        """Exchange authorization code for tokens."""
        client = await self._get_client()

        data = {
            "client_id": self.config.client_id,
            "client_secret": self.config.client_secret,
            "code": code,
            "redirect_uri": self.config.redirect_uri,
            "grant_type": "authorization_code",
        }

        try:
            response = await client.post(self.config.token_url, data=data)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            logger.error(f"OAuth token exchange failed: {e}")
            raise OAuthError(
                self.config.provider.value,
                f"Failed to exchange authorization code: {e}",
            ) from e

    async def refresh_token(self, refresh_token: str) -> dict[str, Any]:
        """Refresh an access token."""
        client = await self._get_client()

        data = {
            "client_id": self.config.client_id,
            "client_secret": self.config.client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }

        try:
            response = await client.post(self.config.token_url, data=data)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            logger.error(f"OAuth token refresh failed: {e}")
            raise OAuthError(
                self.config.provider.value,
                f"Failed to refresh token: {e}",
            ) from e

    async def get_user_info(self, access_token: str) -> dict[str, Any]:
        """Get user info from the provider."""
        client = await self._get_client()

        if self.config.provider == Provider.GMAIL:
            url = "https://www.googleapis.com/oauth2/v2/userinfo"
        else:  # Microsoft
            url = "https://graph.microsoft.com/v1.0/me"

        headers = {"Authorization": f"Bearer {access_token}"}

        try:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            logger.error(f"Failed to get user info: {e}")
            raise OAuthError(
                self.config.provider.value,
                f"Failed to get user info: {e}",
            ) from e


# OAuth client instances
google_oauth = OAuthClient(GOOGLE_CONFIG)
microsoft_oauth = OAuthClient(MICROSOFT_CONFIG)


def get_oauth_client(provider: Provider) -> OAuthClient:
    """Get OAuth client for provider."""
    if provider == Provider.GMAIL:
        return google_oauth
    elif provider == Provider.OUTLOOK:
        return microsoft_oauth
    else:
        raise OAuthError(provider.value, f"OAuth not supported for {provider}")
