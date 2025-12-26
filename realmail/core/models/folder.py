"""Folder models."""

from datetime import datetime
from enum import Enum

from pydantic import Field

from realmail.core.models.base import RealMailModel, TimestampMixin


class FolderType(str, Enum):
    """Standard folder types."""

    INBOX = "inbox"
    SENT = "sent"
    DRAFTS = "drafts"
    TRASH = "trash"
    SPAM = "spam"
    ARCHIVE = "archive"
    CUSTOM = "custom"


# Common folder name patterns for detection
FOLDER_TYPE_PATTERNS: dict[FolderType, list[str]] = {
    FolderType.INBOX: ["inbox", "eingang"],
    FolderType.SENT: ["sent", "sent items", "sent mail", "[gmail]/sent mail", "gesendet"],
    FolderType.DRAFTS: ["drafts", "draft", "[gmail]/drafts", "entwürfe"],
    FolderType.TRASH: ["trash", "deleted", "deleted items", "[gmail]/trash", "papierkorb"],
    FolderType.SPAM: ["spam", "junk", "junk email", "[gmail]/spam"],
    FolderType.ARCHIVE: ["archive", "all mail", "[gmail]/all mail", "archiv"],
}


class FolderBase(RealMailModel):
    """Base folder fields."""

    name: str = Field(min_length=1, max_length=255)
    full_path: str
    folder_type: FolderType = FolderType.CUSTOM


class FolderCreate(FolderBase):
    """Folder creation model."""

    account_id: str
    parent_id: str | None = None
    is_system: bool = False


class Folder(FolderBase, TimestampMixin):
    """Full folder model (database representation)."""

    id: str
    account_id: str
    parent_id: str | None = None
    is_system: bool = False
    imap_uidvalidity: int | None = None
    imap_last_uid: int = 0
    message_count: int = 0
    unread_count: int = 0


class FolderResponse(RealMailModel):
    """Folder response model (API output)."""

    id: str
    name: str
    full_path: str
    folder_type: FolderType
    is_system: bool
    parent_id: str | None
    message_count: int
    unread_count: int
    children: list["FolderResponse"] = Field(default_factory=list)


def detect_folder_type(folder_name: str) -> FolderType:
    """Detect folder type from name."""
    name_lower = folder_name.lower().strip()

    for folder_type, patterns in FOLDER_TYPE_PATTERNS.items():
        if name_lower in patterns:
            return folder_type

    return FolderType.CUSTOM


def is_system_folder(folder_type: FolderType) -> bool:
    """Check if folder type is a system folder."""
    return folder_type != FolderType.CUSTOM
