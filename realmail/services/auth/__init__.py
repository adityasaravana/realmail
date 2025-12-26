"""Authentication service."""

from realmail.services.auth.credentials import CredentialManager
from realmail.services.auth.oauth import OAuthClient
from realmail.services.auth.repository import AccountRepository
from realmail.services.auth.router import router as auth_router
from realmail.services.auth.service import AuthService

__all__ = [
    "auth_router",
    "AuthService",
    "AccountRepository",
    "CredentialManager",
    "OAuthClient",
]
