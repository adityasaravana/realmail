"""Folder synchronization logic."""

from realmail.core.logging import get_logger
from realmail.core.models.folder import (
    Folder,
    FolderType,
    detect_folder_type,
    is_system_folder,
)
from realmail.core.repositories.base import generate_id
from realmail.services.sync.imap_client import IMAPClient
from realmail.services.sync.repository import folder_repository

logger = get_logger(__name__)


class FolderSync:
    """Synchronizes folder structure from IMAP server."""

    def __init__(self, account_id: str, imap_client: IMAPClient) -> None:
        self.account_id = account_id
        self.imap = imap_client

    async def sync(self) -> list[Folder]:
        """Sync folders from IMAP server to database."""
        logger.info(f"Starting folder sync for account {self.account_id}")

        # Get folders from IMAP
        imap_folders = await self.imap.list_folders()
        logger.info(f"Found {len(imap_folders)} folders on server")

        # Get existing folders from database
        existing_folders = await folder_repository.get_by_account(self.account_id)
        existing_by_path = {f.full_path: f for f in existing_folders}

        synced_folders = []
        seen_paths = set()

        for imap_folder in imap_folders:
            full_path = imap_folder["full_path"]
            name = imap_folder["name"]
            flags = imap_folder.get("flags", [])

            # Skip folders with \Noselect flag
            if "\\Noselect" in flags or "\\NoSelect" in flags:
                continue

            seen_paths.add(full_path)

            # Determine folder type
            folder_type = self._detect_type_from_flags(flags) or detect_folder_type(full_path)

            if full_path in existing_by_path:
                # Update existing folder
                existing = existing_by_path[full_path]
                if existing.folder_type != folder_type:
                    folder = await folder_repository.update(existing.id, {
                        "folder_type": folder_type.value,
                        "is_system": is_system_folder(folder_type),
                    })
                else:
                    folder = existing
            else:
                # Create new folder
                folder = await folder_repository.create({
                    "id": generate_id(),
                    "account_id": self.account_id,
                    "name": name,
                    "full_path": full_path,
                    "folder_type": folder_type.value,
                    "is_system": is_system_folder(folder_type),
                })
                logger.info(f"Created folder: {full_path} ({folder_type.value})")

            synced_folders.append(folder)

        # Mark removed folders (don't delete, just log for now)
        for path, folder in existing_by_path.items():
            if path not in seen_paths:
                logger.warning(f"Folder no longer on server: {path}")

        logger.info(f"Folder sync complete: {len(synced_folders)} folders")
        return synced_folders

    def _detect_type_from_flags(self, flags: list[str]) -> FolderType | None:
        """Detect folder type from IMAP SPECIAL-USE flags."""
        flag_map = {
            "\\Inbox": FolderType.INBOX,
            "\\Sent": FolderType.SENT,
            "\\Drafts": FolderType.DRAFTS,
            "\\Trash": FolderType.TRASH,
            "\\Junk": FolderType.SPAM,
            "\\Archive": FolderType.ARCHIVE,
            "\\All": FolderType.ARCHIVE,
        }

        for flag in flags:
            if flag in flag_map:
                return flag_map[flag]

        return None
