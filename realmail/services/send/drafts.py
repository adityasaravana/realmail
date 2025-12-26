"""Draft management."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, EmailStr, Field

from realmail.core.database import get_connection
from realmail.core.repositories.base import BaseRepository, generate_id, now_iso
from realmail.core.models.message import EmailAddress


class Draft(BaseModel):
    """Draft model."""

    id: str
    account_id: str
    to_addresses: list[str] = Field(default_factory=list)
    cc_addresses: list[str] = Field(default_factory=list)
    bcc_addresses: list[str] = Field(default_factory=list)
    subject: str | None = None
    body_plain: str | None = None
    body_html: str | None = None
    reply_to_message_id: str | None = None
    forward_message_id: str | None = None
    imap_uid: int | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class DraftCreate(BaseModel):
    """Draft creation model."""

    to_addresses: list[str] = Field(default_factory=list)
    cc_addresses: list[str] = Field(default_factory=list)
    bcc_addresses: list[str] = Field(default_factory=list)
    subject: str | None = None
    body_plain: str | None = None
    body_html: str | None = None
    reply_to_message_id: str | None = None
    forward_message_id: str | None = None


class DraftUpdate(BaseModel):
    """Draft update model."""

    to_addresses: list[str] | None = None
    cc_addresses: list[str] | None = None
    bcc_addresses: list[str] | None = None
    subject: str | None = None
    body_plain: str | None = None
    body_html: str | None = None


class DraftAttachment(BaseModel):
    """Draft attachment."""

    id: str
    draft_id: str
    filename: str
    content_type: str
    size_bytes: int
    content_base64: str


class DraftRepository(BaseRepository[Draft]):
    """Repository for draft operations."""

    table_name = "drafts"
    model_class = Draft

    async def get_by_account(self, account_id: str) -> list[Draft]:
        """Get all drafts for an account."""
        return await self.find_by(account_id=account_id)


class DraftAttachmentRepository(BaseRepository[DraftAttachment]):
    """Repository for draft attachments."""

    table_name = "draft_attachments"
    model_class = DraftAttachment

    async def get_by_draft(self, draft_id: str) -> list[DraftAttachment]:
        """Get attachments for a draft."""
        return await self.find_by(draft_id=draft_id)

    async def delete_by_draft(self, draft_id: str) -> int:
        """Delete all attachments for a draft."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                "DELETE FROM draft_attachments WHERE draft_id = ?",
                (draft_id,),
            )
            await conn.commit()
            return cursor.rowcount


class DraftService:
    """Service for managing drafts."""

    def __init__(self) -> None:
        self.drafts = DraftRepository()
        self.attachments = DraftAttachmentRepository()

    async def create(self, account_id: str, data: DraftCreate) -> Draft:
        """Create a new draft."""
        draft_data = {
            "id": generate_id(),
            "account_id": account_id,
            **data.model_dump(exclude_none=True),
        }
        return await self.drafts.create(draft_data)

    async def update(self, draft_id: str, data: DraftUpdate) -> Draft:
        """Update a draft."""
        update_data = data.model_dump(exclude_none=True)
        return await self.drafts.update(draft_id, update_data)

    async def get(self, draft_id: str) -> Draft:
        """Get a draft by ID."""
        return await self.drafts.get_by_id_or_raise(draft_id)

    async def list_by_account(self, account_id: str) -> list[Draft]:
        """List drafts for an account."""
        return await self.drafts.get_by_account(account_id)

    async def delete(self, draft_id: str) -> bool:
        """Delete a draft and its attachments."""
        await self.attachments.delete_by_draft(draft_id)
        return await self.drafts.delete(draft_id)

    async def add_attachment(
        self,
        draft_id: str,
        filename: str,
        content_type: str,
        content: bytes,
    ) -> DraftAttachment:
        """Add attachment to draft."""
        import base64

        return await self.attachments.create({
            "id": generate_id(),
            "draft_id": draft_id,
            "filename": filename,
            "content_type": content_type,
            "size_bytes": len(content),
            "content_base64": base64.b64encode(content).decode(),
        })

    async def remove_attachment(self, attachment_id: str) -> bool:
        """Remove attachment from draft."""
        return await self.attachments.delete(attachment_id)

    async def get_attachments(self, draft_id: str) -> list[DraftAttachment]:
        """Get attachments for a draft."""
        return await self.attachments.get_by_draft(draft_id)


# Default instance
draft_service = DraftService()
