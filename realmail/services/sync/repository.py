"""Repositories for folders and messages."""

from typing import Any

from realmail.core.database import get_connection
from realmail.core.models.folder import Folder
from realmail.core.models.message import Message
from realmail.core.repositories.base import BaseRepository


class FolderRepository(BaseRepository[Folder]):
    """Repository for folder operations."""

    table_name = "folders"
    model_class = Folder

    async def get_by_account(self, account_id: str) -> list[Folder]:
        """Get all folders for an account."""
        return await self.find_by(account_id=account_id)

    async def get_by_path(self, account_id: str, full_path: str) -> Folder | None:
        """Get folder by account and path."""
        results = await self.find_by(account_id=account_id, full_path=full_path)
        return results[0] if results else None

    async def get_by_type(self, account_id: str, folder_type: str) -> Folder | None:
        """Get folder by type (inbox, sent, etc.)."""
        results = await self.find_by(account_id=account_id, folder_type=folder_type)
        return results[0] if results else None

    async def update_counts(
        self,
        folder_id: str,
        message_count: int,
        unread_count: int,
    ) -> Folder:
        """Update folder message counts."""
        return await self.update(folder_id, {
            "message_count": message_count,
            "unread_count": unread_count,
        })

    async def update_sync_state(
        self,
        folder_id: str,
        uidvalidity: int,
        last_uid: int,
    ) -> Folder:
        """Update folder sync state."""
        return await self.update(folder_id, {
            "imap_uidvalidity": uidvalidity,
            "imap_last_uid": last_uid,
        })


class MessageRepository(BaseRepository[Message]):
    """Repository for message operations."""

    table_name = "messages"
    model_class = Message

    async def get_by_folder(
        self,
        folder_id: str,
        limit: int = 50,
        offset: int = 0,
    ) -> list[Message]:
        """Get messages in a folder with pagination."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                """
                SELECT * FROM messages
                WHERE folder_id = ?
                ORDER BY date DESC
                LIMIT ? OFFSET ?
                """,
                (folder_id, limit, offset),
            )
            rows = await cursor.fetchall()
            return [self._row_to_model(row) for row in rows]

    async def get_by_uid(self, folder_id: str, imap_uid: int) -> Message | None:
        """Get message by IMAP UID."""
        results = await self.find_by(folder_id=folder_id, imap_uid=imap_uid)
        return results[0] if results else None

    async def get_by_message_id(self, account_id: str, message_id: str) -> Message | None:
        """Get message by RFC Message-ID."""
        results = await self.find_by(account_id=account_id, message_id=message_id)
        return results[0] if results else None

    async def get_thread(self, thread_id: str) -> list[Message]:
        """Get all messages in a thread."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                "SELECT * FROM messages WHERE thread_id = ? ORDER BY date ASC",
                (thread_id,),
            )
            rows = await cursor.fetchall()
            return [self._row_to_model(row) for row in rows]

    async def update_flags(
        self,
        message_id: str,
        is_read: bool | None = None,
        is_starred: bool | None = None,
        is_answered: bool | None = None,
        is_deleted: bool | None = None,
    ) -> Message:
        """Update message flags."""
        data: dict[str, Any] = {}
        if is_read is not None:
            data["is_read"] = is_read
        if is_starred is not None:
            data["is_starred"] = is_starred
        if is_answered is not None:
            data["is_answered"] = is_answered
        if is_deleted is not None:
            data["is_deleted"] = is_deleted

        return await self.update(message_id, data)

    async def count_by_folder(self, folder_id: str) -> int:
        """Count messages in folder."""
        return await self.count("folder_id = ?", (folder_id,))

    async def count_unread_by_folder(self, folder_id: str) -> int:
        """Count unread messages in folder."""
        return await self.count("folder_id = ? AND is_read = 0", (folder_id,))

    async def count_unread_by_account(self, account_id: str) -> int:
        """Count unread messages for account."""
        return await self.count("account_id = ? AND is_read = 0", (account_id,))

    async def get_latest_uid(self, folder_id: str) -> int:
        """Get the highest UID in folder."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                "SELECT MAX(imap_uid) FROM messages WHERE folder_id = ?",
                (folder_id,),
            )
            row = await cursor.fetchone()
            return row[0] if row and row[0] else 0


class AttachmentRepository(BaseRepository):
    """Repository for attachments."""

    table_name = "attachments"

    async def get_by_message(self, message_id: str) -> list[dict]:
        """Get attachments for a message."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                "SELECT * FROM attachments WHERE message_id = ?",
                (message_id,),
            )
            rows = await cursor.fetchall()
            return [dict(row) for row in rows]


# Default instances
folder_repository = FolderRepository()
message_repository = MessageRepository()
attachment_repository = AttachmentRepository()
