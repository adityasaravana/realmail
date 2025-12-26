"""Email synchronization service."""

from realmail.services.sync.imap_client import IMAPClient
from realmail.services.sync.folder_sync import FolderSync
from realmail.services.sync.message_sync import MessageSync
from realmail.services.sync.repository import FolderRepository, MessageRepository
from realmail.services.sync.router import router as sync_router
from realmail.services.sync.service import SyncService

__all__ = [
    "sync_router",
    "SyncService",
    "IMAPClient",
    "FolderSync",
    "MessageSync",
    "FolderRepository",
    "MessageRepository",
]
