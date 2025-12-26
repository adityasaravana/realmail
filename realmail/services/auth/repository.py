"""Account repository for database operations."""

from realmail.core.models.account import Account
from realmail.core.repositories.base import BaseRepository


class AccountRepository(BaseRepository[Account]):
    """Repository for account operations."""

    table_name = "accounts"
    model_class = Account

    async def get_by_email(self, email: str) -> Account | None:
        """Get account by email address."""
        results = await self.find_by(email=email)
        return results[0] if results else None

    async def get_active_accounts(self) -> list[Account]:
        """Get all active accounts."""
        return await self.find_by(status="active")

    async def update_status(
        self,
        account_id: str,
        status: str,
        error_message: str | None = None,
    ) -> Account:
        """Update account status."""
        data = {"status": status}
        if error_message is not None:
            data["last_error"] = error_message
        return await self.update(account_id, data)

    async def update_credentials(
        self,
        account_id: str,
        encrypted_credentials: str,
    ) -> Account:
        """Update encrypted credentials."""
        return await self.update(
            account_id, {"encrypted_credentials": encrypted_credentials}
        )

    async def update_last_sync(self, account_id: str) -> Account:
        """Update last sync timestamp."""
        from realmail.core.repositories.base import now_iso

        return await self.update(account_id, {"last_sync_at": now_iso()})


# Default instance
account_repository = AccountRepository()
