"""Authentication service business logic."""

import time
from typing import Any

from realmail.core.exceptions import (
    AuthError,
    InvalidCredentialsError,
    TokenExpiredError,
)
from realmail.core.logging import get_logger
from realmail.core.models.account import (
    Account,
    AccountCreate,
    AccountResponse,
    AccountStatus,
    AuthType,
    Provider,
    PROVIDER_CONFIGS,
    SecurityType,
)
from realmail.core.repositories.base import generate_id
from realmail.services.auth.credentials import credential_manager
from realmail.services.auth.oauth import get_oauth_client, OAuthClient
from realmail.services.auth.repository import account_repository

logger = get_logger(__name__)


class AuthService:
    """Service for authentication and account management."""

    async def create_account_from_oauth(
        self,
        provider: Provider,
        code: str,
        state: str,
    ) -> AccountResponse:
        """Create account from OAuth callback."""
        oauth_client = get_oauth_client(provider)

        # Verify state
        if not oauth_client.verify_state(state):
            raise AuthError("Invalid OAuth state parameter")

        # Exchange code for tokens
        tokens = await oauth_client.exchange_code(code)
        access_token = tokens["access_token"]
        refresh_token = tokens.get("refresh_token")
        expires_in = tokens.get("expires_in", 3600)
        expires_at = int(time.time()) + expires_in

        # Get user info
        user_info = await oauth_client.get_user_info(access_token)
        email = user_info.get("email") or user_info.get("mail")
        name = user_info.get("name") or user_info.get("displayName")

        if not email:
            raise AuthError("Could not get email from OAuth provider")

        # Check if account exists
        existing = await account_repository.get_by_email(email)
        if existing:
            # Update tokens
            encrypted = credential_manager.encrypt_oauth_tokens(
                access_token, refresh_token, expires_at
            )
            await account_repository.update_credentials(existing.id, encrypted)
            await account_repository.update_status(existing.id, AccountStatus.ACTIVE.value)
            account = await account_repository.get_by_id_or_raise(existing.id)
        else:
            # Create new account
            config = PROVIDER_CONFIGS.get(provider, {})
            encrypted = credential_manager.encrypt_oauth_tokens(
                access_token, refresh_token, expires_at
            )

            account = await account_repository.create({
                "id": generate_id(),
                "email": email,
                "display_name": name,
                "provider": provider.value,
                "imap_host": config.get("imap_host", ""),
                "imap_port": config.get("imap_port", 993),
                "imap_security": config.get("imap_security", "SSL"),
                "smtp_host": config.get("smtp_host", ""),
                "smtp_port": config.get("smtp_port", 587),
                "smtp_security": config.get("smtp_security", "STARTTLS"),
                "auth_type": AuthType.OAUTH2.value,
                "encrypted_credentials": encrypted,
                "status": AccountStatus.ACTIVE.value,
            })

        return self._to_response(account)

    async def create_account_with_password(
        self,
        email: str,
        password: str,
        imap_host: str,
        imap_port: int = 993,
        imap_security: SecurityType = SecurityType.SSL,
        smtp_host: str | None = None,
        smtp_port: int = 587,
        smtp_security: SecurityType = SecurityType.STARTTLS,
        display_name: str | None = None,
    ) -> AccountResponse:
        """Create account with password credentials."""
        # Check if account exists
        existing = await account_repository.get_by_email(email)
        if existing:
            raise AuthError(f"Account with email {email} already exists")

        # Encrypt password
        encrypted = credential_manager.encrypt_password(password)

        account = await account_repository.create({
            "id": generate_id(),
            "email": email,
            "display_name": display_name,
            "provider": Provider.IMAP.value,
            "imap_host": imap_host,
            "imap_port": imap_port,
            "imap_security": imap_security.value,
            "smtp_host": smtp_host or imap_host.replace("imap", "smtp"),
            "smtp_port": smtp_port,
            "smtp_security": smtp_security.value,
            "auth_type": AuthType.PASSWORD.value,
            "encrypted_credentials": encrypted,
            "status": AccountStatus.ACTIVE.value,
        })

        return self._to_response(account)

    async def get_account(self, account_id: str) -> AccountResponse:
        """Get account by ID."""
        account = await account_repository.get_by_id_or_raise(account_id)
        return self._to_response(account)

    async def list_accounts(self) -> list[AccountResponse]:
        """List all accounts."""
        accounts = await account_repository.get_all()
        return [self._to_response(a) for a in accounts]

    async def delete_account(self, account_id: str) -> bool:
        """Delete an account."""
        # TODO: Revoke OAuth tokens if applicable
        return await account_repository.delete(account_id)

    async def get_credentials(self, account_id: str) -> dict[str, Any]:
        """Get decrypted credentials for an account."""
        account = await account_repository.get_by_id_or_raise(account_id)

        if not account.encrypted_credentials:
            raise AuthError("No credentials stored for account")

        credentials = credential_manager.decrypt(account.encrypted_credentials)

        # Check if OAuth token needs refresh
        if credentials.get("type") == "oauth2":
            expires_at = credentials.get("expires_at", 0)
            if expires_at and time.time() > expires_at - 300:  # 5 min buffer
                credentials = await self._refresh_oauth_token(account, credentials)

        return credentials

    async def _refresh_oauth_token(
        self,
        account: Account,
        credentials: dict[str, Any],
    ) -> dict[str, Any]:
        """Refresh OAuth token if expired."""
        refresh_token = credentials.get("refresh_token")
        if not refresh_token:
            await account_repository.update_status(
                account.id,
                AccountStatus.REQUIRES_REAUTH.value,
                "No refresh token available",
            )
            raise TokenExpiredError(account.id)

        try:
            oauth_client = get_oauth_client(Provider(account.provider))
            tokens = await oauth_client.refresh_token(refresh_token)

            new_access = tokens["access_token"]
            new_refresh = tokens.get("refresh_token", refresh_token)
            expires_in = tokens.get("expires_in", 3600)
            expires_at = int(time.time()) + expires_in

            # Update stored credentials
            encrypted = credential_manager.encrypt_oauth_tokens(
                new_access, new_refresh, expires_at
            )
            await account_repository.update_credentials(account.id, encrypted)

            return {
                "type": "oauth2",
                "access_token": new_access,
                "refresh_token": new_refresh,
                "expires_at": expires_at,
            }

        except Exception as e:
            logger.error(f"Token refresh failed for {account.id}: {e}")
            await account_repository.update_status(
                account.id,
                AccountStatus.REQUIRES_REAUTH.value,
                str(e),
            )
            raise TokenExpiredError(account.id) from e

    async def verify_account(self, account_id: str) -> dict[str, Any]:
        """Verify account can connect to servers."""
        account = await account_repository.get_by_id_or_raise(account_id)
        credentials = await self.get_credentials(account_id)

        result = {
            "imap": {"success": False, "error": None},
            "smtp": {"success": False, "error": None},
        }

        # TODO: Actually test connections when sync/send services are ready
        # For now, just validate credentials exist
        if credentials:
            result["imap"]["success"] = True
            result["smtp"]["success"] = True

        return result

    def _to_response(self, account: Account) -> AccountResponse:
        """Convert Account to AccountResponse."""
        return AccountResponse(
            id=account.id,
            email=account.email,
            display_name=account.display_name,
            provider=Provider(account.provider),
            imap_host=account.imap_host,
            smtp_host=account.smtp_host,
            auth_type=AuthType(account.auth_type),
            status=AccountStatus(account.status),
            last_sync_at=account.last_sync_at,
            folder_count=0,  # TODO: Get from folder repository
            unread_count=0,  # TODO: Get from message repository
            created_at=account.created_at,
        )


# Default instance
auth_service = AuthService()
