"""Shared Pydantic models."""

from realmail.core.models.account import (
    Account,
    AccountCreate,
    AccountResponse,
    AccountStatus,
    AccountUpdate,
    AuthType,
    Provider,
    SecurityType,
)
from realmail.core.models.attachment import (
    Attachment,
    AttachmentCreate,
    AttachmentResponse,
)
from realmail.core.models.folder import (
    Folder,
    FolderCreate,
    FolderResponse,
    FolderType,
)
from realmail.core.models.message import (
    EmailAddress,
    Message,
    MessageCreate,
    MessageResponse,
    MessageUpdate,
)

__all__ = [
    # Account
    "Account",
    "AccountCreate",
    "AccountResponse",
    "AccountStatus",
    "AccountUpdate",
    "AuthType",
    "Provider",
    "SecurityType",
    # Folder
    "Folder",
    "FolderCreate",
    "FolderResponse",
    "FolderType",
    # Message
    "EmailAddress",
    "Message",
    "MessageCreate",
    "MessageResponse",
    "MessageUpdate",
    # Attachment
    "Attachment",
    "AttachmentCreate",
    "AttachmentResponse",
]
