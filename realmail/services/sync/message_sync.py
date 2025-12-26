"""Message synchronization logic."""

import json
from typing import Any

from realmail.core.logging import get_logger
from realmail.core.mime import ParsedMessage, parse_mime_message, get_snippet
from realmail.core.models.folder import Folder
from realmail.core.models.message import Message
from realmail.core.repositories.base import generate_id
from realmail.services.sync.imap_client import IMAPClient
from realmail.services.sync.repository import (
    folder_repository,
    message_repository,
    attachment_repository,
)

logger = get_logger(__name__)


class MessageSync:
    """Synchronizes messages from IMAP server."""

    def __init__(self, account_id: str, imap_client: IMAPClient) -> None:
        self.account_id = account_id
        self.imap = imap_client

    async def sync_folder(self, folder: Folder, full_sync: bool = False) -> int:
        """Sync messages in a folder. Returns count of new messages."""
        logger.info(f"Syncing messages in {folder.full_path}")

        # Select folder and get status
        status = await self.imap.select_folder(folder.full_path)
        current_uidvalidity = status.get("uidvalidity")
        exists_count = status.get("exists", 0)

        if exists_count == 0:
            logger.info(f"Folder {folder.full_path} is empty")
            await folder_repository.update_counts(folder.id, 0, 0)
            return 0

        # Check UIDVALIDITY
        if folder.imap_uidvalidity and current_uidvalidity != folder.imap_uidvalidity:
            logger.warning(f"UIDVALIDITY changed for {folder.full_path}, forcing full sync")
            full_sync = True

        # Determine which UIDs to fetch
        if full_sync:
            since_uid = 0
        else:
            since_uid = folder.imap_last_uid or 0

        # Get UIDs to sync
        uids = await self.imap.fetch_uids(folder.full_path, since_uid)
        logger.info(f"Found {len(uids)} messages to sync (since UID {since_uid})")

        if not uids:
            return 0

        # Sync each message
        synced = 0
        max_uid = since_uid

        for uid in uids:
            try:
                # Check if we already have this message
                existing = await message_repository.get_by_uid(folder.id, uid)
                if existing:
                    # Just sync flags
                    await self._sync_flags(folder, existing, uid)
                else:
                    # Fetch and store new message
                    await self._fetch_and_store(folder, uid)
                    synced += 1

                max_uid = max(max_uid, uid)

            except Exception as e:
                logger.error(f"Error syncing UID {uid}: {e}")
                continue

        # Update folder sync state
        if current_uidvalidity:
            await folder_repository.update_sync_state(
                folder.id, current_uidvalidity, max_uid
            )

        # Update counts
        total = await message_repository.count_by_folder(folder.id)
        unread = await message_repository.count_unread_by_folder(folder.id)
        await folder_repository.update_counts(folder.id, total, unread)

        logger.info(f"Synced {synced} new messages in {folder.full_path}")
        return synced

    async def _fetch_and_store(self, folder: Folder, uid: int) -> Message | None:
        """Fetch a message and store it."""
        raw_message = await self.imap.fetch_message(folder.full_path, uid)
        if not raw_message:
            logger.warning(f"Could not fetch UID {uid}")
            return None

        # Parse message
        parsed = parse_mime_message(raw_message)

        # Get flags
        flags = await self.imap.fetch_flags(folder.full_path, uid)
        is_read = "\\Seen" in flags
        is_starred = "\\Flagged" in flags
        is_answered = "\\Answered" in flags
        is_deleted = "\\Deleted" in flags
        is_draft = "\\Draft" in flags

        # Compute thread ID
        thread_id = self._compute_thread_id(parsed)

        # Create message record
        message_data = {
            "id": generate_id(),
            "account_id": self.account_id,
            "folder_id": folder.id,
            "imap_uid": uid,
            "message_id": parsed.message_id,
            "thread_id": thread_id,
            "in_reply_to": parsed.in_reply_to,
            "references": parsed.references,
            "from_address": parsed.from_address.address if parsed.from_address else "",
            "from_name": parsed.from_address.name if parsed.from_address else None,
            "to_addresses": [str(a) for a in parsed.to_addresses],
            "cc_addresses": [str(a) for a in parsed.cc_addresses],
            "bcc_addresses": [str(a) for a in parsed.bcc_addresses],
            "reply_to": str(parsed.reply_to) if parsed.reply_to else None,
            "subject": parsed.subject,
            "date": parsed.date.isoformat(),
            "body_plain": parsed.body_plain,
            "body_html": parsed.body_html,
            "snippet": get_snippet(parsed.body_plain, parsed.body_html),
            "has_attachments": len(parsed.attachments) > 0,
            "is_read": is_read,
            "is_starred": is_starred,
            "is_answered": is_answered,
            "is_draft": is_draft,
            "is_deleted": is_deleted,
            "raw_headers": parsed.headers,
            "size_bytes": parsed.size_bytes,
        }

        message = await message_repository.create(message_data)

        # Store attachments
        for att in parsed.attachments:
            await attachment_repository.create({
                "id": generate_id(),
                "message_id": message.id,
                "filename": att.filename,
                "content_type": att.content_type,
                "content_id": att.content_id,
                "size_bytes": att.size_bytes,
                "is_inline": att.is_inline,
                "content_base64": att.content_base64,
            })

        return message

    async def _sync_flags(self, folder: Folder, message: Message, uid: int) -> None:
        """Sync flags for existing message."""
        flags = await self.imap.fetch_flags(folder.full_path, uid)

        is_read = "\\Seen" in flags
        is_starred = "\\Flagged" in flags
        is_answered = "\\Answered" in flags
        is_deleted = "\\Deleted" in flags

        # Only update if changed
        if (
            message.is_read != is_read
            or message.is_starred != is_starred
            or message.is_answered != is_answered
            or message.is_deleted != is_deleted
        ):
            await message_repository.update_flags(
                message.id,
                is_read=is_read,
                is_starred=is_starred,
                is_answered=is_answered,
                is_deleted=is_deleted,
            )

    def _compute_thread_id(self, parsed: ParsedMessage) -> str:
        """Compute thread ID from message references."""
        # Use the first message-id in the references chain, or own message-id
        if parsed.references:
            return parsed.references[0].strip("<>")
        if parsed.in_reply_to:
            return parsed.in_reply_to.strip("<>")
        if parsed.message_id:
            return parsed.message_id.strip("<>")
        return generate_id()

    async def update_flags_on_server(
        self,
        message: Message,
        is_read: bool | None = None,
        is_starred: bool | None = None,
    ) -> None:
        """Update message flags on IMAP server."""
        if message.imap_uid is None:
            return

        folder = await folder_repository.get_by_id(message.folder_id)
        if not folder:
            return

        if is_read is not None:
            if is_read:
                await self.imap.set_flags(folder.full_path, message.imap_uid, ["\\Seen"], add=True)
            else:
                await self.imap.set_flags(folder.full_path, message.imap_uid, ["\\Seen"], add=False)

        if is_starred is not None:
            if is_starred:
                await self.imap.set_flags(folder.full_path, message.imap_uid, ["\\Flagged"], add=True)
            else:
                await self.imap.set_flags(folder.full_path, message.imap_uid, ["\\Flagged"], add=False)
