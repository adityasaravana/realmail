"""Attachment models."""

import base64
import mimetypes
from datetime import datetime

from pydantic import Field, field_validator

from realmail.core.models.base import RealMailModel


class AttachmentBase(RealMailModel):
    """Base attachment fields."""

    filename: str = Field(min_length=1, max_length=255)
    content_type: str
    size_bytes: int = Field(ge=0)


class AttachmentCreate(AttachmentBase):
    """Attachment creation model."""

    content: bytes
    content_id: str | None = None  # For inline attachments
    is_inline: bool = False

    @field_validator("content_type", mode="before")
    @classmethod
    def detect_content_type(cls, v: str | None, info) -> str:
        if v:
            return v
        # Try to detect from filename
        filename = info.data.get("filename", "")
        detected, _ = mimetypes.guess_type(filename)
        return detected or "application/octet-stream"

    @property
    def content_base64(self) -> str:
        return base64.b64encode(self.content).decode("utf-8")


class Attachment(AttachmentBase):
    """Full attachment model (database representation)."""

    id: str
    message_id: str
    content_id: str | None = None
    is_inline: bool = False
    content_base64: str | None = None
    created_at: datetime | None = None

    @property
    def content(self) -> bytes | None:
        """Decode content from base64."""
        if self.content_base64:
            return base64.b64decode(self.content_base64)
        return None


class AttachmentResponse(RealMailModel):
    """Attachment response model (API output)."""

    id: str
    filename: str
    content_type: str
    size_bytes: int
    is_inline: bool
    content_id: str | None = None

    # Content is not included by default (download separately)
