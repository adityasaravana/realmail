"""Send service orchestration."""

import base64
from typing import Any

from realmail.core.exceptions import AttachmentTooLargeError
from realmail.core.config import settings
from realmail.core.logging import get_logger
from realmail.core.models.attachment import AttachmentCreate
from realmail.core.models.message import EmailAddress, Message, MessageResponse
from realmail.core.repositories.base import generate_id
from realmail.services.auth.repository import account_repository
from realmail.services.auth.service import auth_service
from realmail.services.send.composer import message_composer
from realmail.services.send.drafts import draft_service, Draft, DraftCreate, DraftUpdate
from realmail.services.send.queue import send_queue, SendStatus
from realmail.services.send.smtp_client import SMTPClient
from realmail.services.sync.repository import folder_repository, message_repository
from realmail.services.sync.imap_client import IMAPClient

logger = get_logger(__name__)


class SendService:
    """Service for sending emails."""

    async def send_message(
        self,
        account_id: str,
        to_addresses: list[str],
        subject: str,
        body_plain: str | None = None,
        body_html: str | None = None,
        cc_addresses: list[str] | None = None,
        bcc_addresses: list[str] | None = None,
        attachments: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        """Send a new message."""
        account = await account_repository.get_by_id_or_raise(account_id)

        # Validate attachments
        if attachments:
            total_size = sum(a.get("size_bytes", 0) for a in attachments)
            if total_size > settings.max_attachment_size_bytes:
                raise AttachmentTooLargeError(total_size, settings.max_attachment_size_bytes)

        # Build from address
        from_addr = EmailAddress(
            address=account.email,
            name=account.display_name,
        )

        # Parse recipients
        to_list = [EmailAddress.parse(a) for a in to_addresses]
        cc_list = [EmailAddress.parse(a) for a in (cc_addresses or [])]
        bcc_list = [EmailAddress.parse(a) for a in (bcc_addresses or [])]

        # Build attachments
        att_list = None
        if attachments:
            att_list = [
                AttachmentCreate(
                    filename=a["filename"],
                    content_type=a["content_type"],
                    size_bytes=a["size_bytes"],
                    content=base64.b64decode(a["content_base64"]),
                )
                for a in attachments
            ]

        # Compose message
        message = message_composer.compose(
            from_address=from_addr,
            to_addresses=to_list,
            subject=subject,
            body_plain=body_plain,
            body_html=body_html,
            cc_addresses=cc_list if cc_list else None,
            bcc_addresses=bcc_list if bcc_list else None,
            attachments=att_list,
        )

        # Get all recipients for SMTP
        all_recipients = (
            [a.address for a in to_list]
            + [a.address for a in cc_list]
            + [a.address for a in bcc_list]
        )

        message_bytes = message.as_bytes()
        message_id = generate_id()

        # Queue for sending
        queued = await send_queue.enqueue(
            message_id=message_id,
            account_id=account_id,
            message_bytes=message_bytes,
            from_address=account.email,
            to_addresses=[a.address for a in to_list],
            cc_addresses=[a.address for a in cc_list],
            bcc_addresses=[a.address for a in bcc_list],
        )

        return {
            "message_id": message_id,
            "status": queued.status.value,
        }

    async def send_reply(
        self,
        account_id: str,
        message_id: str,
        body_plain: str | None = None,
        body_html: str | None = None,
        reply_all: bool = False,
        attachments: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        """Reply to a message."""
        account = await account_repository.get_by_id_or_raise(account_id)
        original = await message_repository.get_by_id_or_raise(message_id)

        from_addr = EmailAddress(
            address=account.email,
            name=account.display_name,
        )

        # Build attachments
        att_list = None
        if attachments:
            att_list = [
                AttachmentCreate(
                    filename=a["filename"],
                    content_type=a["content_type"],
                    size_bytes=a["size_bytes"],
                    content=base64.b64decode(a["content_base64"]),
                )
                for a in attachments
            ]

        message = message_composer.compose_reply(
            original=original,
            from_address=from_addr,
            body_plain=body_plain,
            body_html=body_html,
            reply_all=reply_all,
            attachments=att_list,
        )

        # Extract recipients from composed message
        to_addrs = message.get("To", "").split(", ")
        cc_addrs = message.get("Cc", "").split(", ") if message.get("Cc") else []

        message_bytes = message.as_bytes()
        new_message_id = generate_id()

        queued = await send_queue.enqueue(
            message_id=new_message_id,
            account_id=account_id,
            message_bytes=message_bytes,
            from_address=account.email,
            to_addresses=to_addrs,
            cc_addresses=cc_addrs,
        )

        return {
            "message_id": new_message_id,
            "status": queued.status.value,
        }

    async def send_forward(
        self,
        account_id: str,
        message_id: str,
        to_addresses: list[str],
        body_plain: str | None = None,
        body_html: str | None = None,
        include_attachments: bool = True,
    ) -> dict[str, Any]:
        """Forward a message."""
        account = await account_repository.get_by_id_or_raise(account_id)
        original = await message_repository.get_by_id_or_raise(message_id)

        from_addr = EmailAddress(
            address=account.email,
            name=account.display_name,
        )

        to_list = [EmailAddress.parse(a) for a in to_addresses]

        message = message_composer.compose_forward(
            original=original,
            from_address=from_addr,
            to_addresses=to_list,
            body_plain=body_plain,
            body_html=body_html,
            include_attachments=include_attachments,
        )

        message_bytes = message.as_bytes()
        new_message_id = generate_id()

        queued = await send_queue.enqueue(
            message_id=new_message_id,
            account_id=account_id,
            message_bytes=message_bytes,
            from_address=account.email,
            to_addresses=[a.address for a in to_list],
        )

        return {
            "message_id": new_message_id,
            "status": queued.status.value,
        }

    async def send_draft(self, draft_id: str) -> dict[str, Any]:
        """Send a draft."""
        draft = await draft_service.get(draft_id)
        account = await account_repository.get_by_id_or_raise(draft.account_id)

        # Get draft attachments
        attachments = await draft_service.get_attachments(draft_id)

        result = await self.send_message(
            account_id=draft.account_id,
            to_addresses=draft.to_addresses,
            subject=draft.subject or "",
            body_plain=draft.body_plain,
            body_html=draft.body_html,
            cc_addresses=draft.cc_addresses,
            bcc_addresses=draft.bcc_addresses,
            attachments=[
                {
                    "filename": a.filename,
                    "content_type": a.content_type,
                    "size_bytes": a.size_bytes,
                    "content_base64": a.content_base64,
                }
                for a in attachments
            ] if attachments else None,
        )

        # Delete draft after queuing
        await draft_service.delete(draft_id)

        return result

    async def send_raw(
        self,
        account_id: str,
        message_bytes: bytes,
        from_address: str,
        to_addresses: list[str],
    ) -> dict[str, Any]:
        """Send raw message bytes via SMTP."""
        account = await account_repository.get_by_id_or_raise(account_id)
        credentials = await auth_service.get_credentials(account_id)

        smtp = SMTPClient(account)
        try:
            await smtp.connect(credentials)
            result = await smtp.send(message_bytes, from_address, to_addresses)

            # Copy to Sent folder
            await self._copy_to_sent(account_id, message_bytes)

            return result

        finally:
            await smtp.disconnect()

    async def _copy_to_sent(self, account_id: str, message_bytes: bytes) -> None:
        """Copy sent message to Sent folder via IMAP."""
        try:
            account = await account_repository.get_by_id_or_raise(account_id)
            credentials = await auth_service.get_credentials(account_id)

            # Find Sent folder
            sent_folder = await folder_repository.get_by_type(account_id, "sent")
            if not sent_folder:
                logger.warning(f"No Sent folder found for account {account_id}")
                return

            imap = IMAPClient(account)
            try:
                await imap.connect(credentials)
                await imap.append_message(
                    sent_folder.full_path,
                    message_bytes,
                    ["\\Seen"],
                )
            finally:
                await imap.disconnect()

        except Exception as e:
            logger.error(f"Failed to copy to Sent folder: {e}")

    async def get_send_status(self, message_id: str) -> dict[str, Any]:
        """Get status of a queued message."""
        status = await send_queue.get_status(message_id)
        if not status:
            return {"status": "not_found"}

        return {
            "message_id": status.id,
            "status": status.status.value,
            "attempts": status.attempts,
            "error": status.error,
            "created_at": status.created_at,
            "updated_at": status.updated_at,
        }

    # Draft management passthrough
    async def create_draft(self, account_id: str, data: DraftCreate) -> Draft:
        return await draft_service.create(account_id, data)

    async def update_draft(self, draft_id: str, data: DraftUpdate) -> Draft:
        return await draft_service.update(draft_id, data)

    async def get_draft(self, draft_id: str) -> Draft:
        return await draft_service.get(draft_id)

    async def list_drafts(self, account_id: str) -> list[Draft]:
        return await draft_service.list_by_account(account_id)

    async def delete_draft(self, draft_id: str) -> bool:
        return await draft_service.delete(draft_id)


# Default instance
send_service = SendService()
