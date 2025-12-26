"""Sync service orchestration."""

import asyncio
from typing import Any

from realmail.core.cache import pubsub
from realmail.core.logging import get_logger, set_log_context
from realmail.core.models.account import Account
from realmail.core.models.folder import Folder
from realmail.core.models.message import Message, MessageResponse
from realmail.services.auth.repository import account_repository
from realmail.services.auth.service import auth_service
from realmail.services.sync.folder_sync import FolderSync
from realmail.services.sync.imap_client import IMAPClient
from realmail.services.sync.message_sync import MessageSync
from realmail.services.sync.repository import folder_repository, message_repository

logger = get_logger(__name__)


class SyncService:
    """Service for email synchronization."""

    def __init__(self) -> None:
        self._sync_tasks: dict[str, asyncio.Task] = {}

    async def sync_account(self, account_id: str, full_sync: bool = False) -> dict[str, Any]:
        """Sync all folders for an account."""
        set_log_context(account_id=account_id)
        logger.info(f"Starting sync for account {account_id}")

        account = await account_repository.get_by_id_or_raise(account_id)
        credentials = await auth_service.get_credentials(account_id)

        # Create IMAP client
        imap = IMAPClient(account)
        try:
            await imap.connect(credentials)

            # Sync folders first
            folder_sync = FolderSync(account_id, imap)
            folders = await folder_sync.sync()

            # Sync messages in each folder
            message_sync = MessageSync(account_id, imap)
            total_new = 0

            for folder in folders:
                try:
                    new_count = await message_sync.sync_folder(folder, full_sync)
                    total_new += new_count

                    # Publish event for new messages
                    if new_count > 0:
                        await pubsub.publish("new_messages", {
                            "account_id": account_id,
                            "folder_id": folder.id,
                            "count": new_count,
                        })

                except Exception as e:
                    logger.error(f"Error syncing folder {folder.full_path}: {e}")

            # Update account last sync
            await account_repository.update_last_sync(account_id)

            return {
                "account_id": account_id,
                "folders_synced": len(folders),
                "new_messages": total_new,
            }

        finally:
            await imap.disconnect()

    async def sync_folder(self, folder_id: str, full_sync: bool = False) -> dict[str, Any]:
        """Sync a specific folder."""
        folder = await folder_repository.get_by_id_or_raise(folder_id)
        account = await account_repository.get_by_id_or_raise(folder.account_id)
        credentials = await auth_service.get_credentials(account.id)

        imap = IMAPClient(account)
        try:
            await imap.connect(credentials)
            message_sync = MessageSync(account.id, imap)
            new_count = await message_sync.sync_folder(folder, full_sync)

            return {
                "folder_id": folder_id,
                "new_messages": new_count,
            }

        finally:
            await imap.disconnect()

    async def get_folders(self, account_id: str) -> list[Folder]:
        """Get all folders for an account."""
        return await folder_repository.get_by_account(account_id)

    async def get_messages(
        self,
        folder_id: str,
        limit: int = 50,
        offset: int = 0,
    ) -> list[MessageResponse]:
        """Get messages in a folder."""
        messages = await message_repository.get_by_folder(folder_id, limit, offset)
        return [MessageResponse.from_message(m) for m in messages]

    async def get_message(self, message_id: str) -> MessageResponse:
        """Get a single message with full body."""
        message = await message_repository.get_by_id_or_raise(message_id)

        # Mark as read if not already
        if not message.is_read:
            await self.update_flags(message_id, is_read=True)

        return MessageResponse.from_message(message, include_body=True)

    async def get_thread(self, message_id: str) -> list[MessageResponse]:
        """Get all messages in a thread."""
        message = await message_repository.get_by_id_or_raise(message_id)
        if not message.thread_id:
            return [MessageResponse.from_message(message, include_body=True)]

        messages = await message_repository.get_thread(message.thread_id)
        return [MessageResponse.from_message(m, include_body=True) for m in messages]

    async def update_flags(
        self,
        message_id: str,
        is_read: bool | None = None,
        is_starred: bool | None = None,
    ) -> MessageResponse:
        """Update message flags locally and on server."""
        message = await message_repository.get_by_id_or_raise(message_id)

        # Update in database
        updated = await message_repository.update_flags(
            message_id,
            is_read=is_read,
            is_starred=is_starred,
        )

        # Update on IMAP server (async, don't block)
        asyncio.create_task(self._update_flags_on_server(message, is_read, is_starred))

        return MessageResponse.from_message(updated)

    async def _update_flags_on_server(
        self,
        message: Message,
        is_read: bool | None,
        is_starred: bool | None,
    ) -> None:
        """Background task to update flags on IMAP server."""
        try:
            folder = await folder_repository.get_by_id(message.folder_id)
            if not folder:
                return

            account = await account_repository.get_by_id(folder.account_id)
            if not account:
                return

            credentials = await auth_service.get_credentials(account.id)

            imap = IMAPClient(account)
            try:
                await imap.connect(credentials)
                message_sync = MessageSync(account.id, imap)
                await message_sync.update_flags_on_server(message, is_read, is_starred)
            finally:
                await imap.disconnect()

        except Exception as e:
            logger.error(f"Failed to update flags on server: {e}")

    def start_background_sync(self, account_id: str, interval: int = 60) -> None:
        """Start background sync for an account."""
        if account_id in self._sync_tasks:
            return

        async def sync_loop():
            while True:
                try:
                    await self.sync_account(account_id)
                except Exception as e:
                    logger.error(f"Background sync failed: {e}")
                await asyncio.sleep(interval)

        task = asyncio.create_task(sync_loop())
        self._sync_tasks[account_id] = task

    def stop_background_sync(self, account_id: str) -> None:
        """Stop background sync for an account."""
        if account_id in self._sync_tasks:
            self._sync_tasks[account_id].cancel()
            del self._sync_tasks[account_id]


# Default instance
sync_service = SyncService()
