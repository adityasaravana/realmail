"""Message models."""

import re
from datetime import datetime

from pydantic import EmailStr, Field, field_validator

from realmail.core.models.base import RealMailModel, TimestampMixin


class EmailAddress(RealMailModel):
    """Email address with optional display name."""

    address: EmailStr
    name: str | None = None

    def __str__(self) -> str:
        if self.name:
            return f'"{self.name}" <{self.address}>'
        return self.address

    @classmethod
    def parse(cls, raw: str) -> "EmailAddress":
        """Parse email from 'Name <email>' or 'email' format."""
        # Pattern: "Name" <email> or Name <email> or just email
        match = re.match(r'^(?:"?([^"<]+)"?\s*)?<?([^>]+)>?$', raw.strip())
        if match:
            name, address = match.groups()
            return cls(address=address.strip(), name=name.strip() if name else None)
        return cls(address=raw.strip())


class MessageBase(RealMailModel):
    """Base message fields."""

    subject: str | None = None
    body_plain: str | None = None
    body_html: str | None = None


class MessageCreate(MessageBase):
    """Message creation model (for sending)."""

    from_address: EmailAddress
    to_addresses: list[EmailAddress] = Field(min_length=1)
    cc_addresses: list[EmailAddress] = Field(default_factory=list)
    bcc_addresses: list[EmailAddress] = Field(default_factory=list)
    reply_to: EmailAddress | None = None
    in_reply_to: str | None = None  # Message-ID of parent
    references: list[str] = Field(default_factory=list)

    @field_validator("to_addresses", "cc_addresses", "bcc_addresses", mode="before")
    @classmethod
    def parse_addresses(cls, v: list) -> list[EmailAddress]:
        if not v:
            return []
        result = []
        for item in v:
            if isinstance(item, str):
                result.append(EmailAddress.parse(item))
            elif isinstance(item, dict):
                result.append(EmailAddress(**item))
            else:
                result.append(item)
        return result


class MessageUpdate(RealMailModel):
    """Message update model (flags only)."""

    is_read: bool | None = None
    is_starred: bool | None = None
    is_deleted: bool | None = None


class Message(MessageBase, TimestampMixin):
    """Full message model (database representation)."""

    id: str
    account_id: str
    folder_id: str
    imap_uid: int | None = None
    message_id: str | None = None  # RFC Message-ID
    thread_id: str | None = None
    in_reply_to: str | None = None
    references: list[str] = Field(default_factory=list)

    from_address: str
    from_name: str | None = None
    to_addresses: list[str] = Field(default_factory=list)
    cc_addresses: list[str] = Field(default_factory=list)
    bcc_addresses: list[str] = Field(default_factory=list)
    reply_to: str | None = None

    date: datetime
    snippet: str | None = None
    has_attachments: bool = False
    is_read: bool = False
    is_starred: bool = False
    is_answered: bool = False
    is_draft: bool = False
    is_deleted: bool = False
    raw_headers: dict[str, str] = Field(default_factory=dict)
    size_bytes: int = 0


class MessageResponse(RealMailModel):
    """Message response model (API output)."""

    id: str
    folder_id: str
    message_id: str | None
    thread_id: str | None

    from_address: EmailAddress
    to_addresses: list[EmailAddress]
    cc_addresses: list[EmailAddress]
    bcc_addresses: list[EmailAddress]
    reply_to: EmailAddress | None

    subject: str | None
    date: datetime
    snippet: str | None
    body_plain: str | None = None
    body_html: str | None = None

    has_attachments: bool
    is_read: bool
    is_starred: bool
    is_answered: bool
    is_draft: bool

    attachments: list["AttachmentResponse"] = Field(default_factory=list)

    @classmethod
    def from_message(cls, msg: Message, include_body: bool = False) -> "MessageResponse":
        """Convert Message to MessageResponse."""
        from realmail.core.models.attachment import AttachmentResponse

        return cls(
            id=msg.id,
            folder_id=msg.folder_id,
            message_id=msg.message_id,
            thread_id=msg.thread_id,
            from_address=EmailAddress(address=msg.from_address, name=msg.from_name),
            to_addresses=[EmailAddress.parse(a) for a in msg.to_addresses],
            cc_addresses=[EmailAddress.parse(a) for a in msg.cc_addresses],
            bcc_addresses=[EmailAddress.parse(a) for a in msg.bcc_addresses],
            reply_to=EmailAddress.parse(msg.reply_to) if msg.reply_to else None,
            subject=msg.subject,
            date=msg.date,
            snippet=msg.snippet,
            body_plain=msg.body_plain if include_body else None,
            body_html=msg.body_html if include_body else None,
            has_attachments=msg.has_attachments,
            is_read=msg.is_read,
            is_starred=msg.is_starred,
            is_answered=msg.is_answered,
            is_draft=msg.is_draft,
            attachments=[],
        )


# Avoid circular import
from realmail.core.models.attachment import AttachmentResponse

MessageResponse.model_rebuild()
