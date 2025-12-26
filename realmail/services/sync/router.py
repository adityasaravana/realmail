"""FastAPI router for sync endpoints."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from realmail.core.exceptions import RecordNotFoundError
from realmail.core.models.folder import FolderResponse, Folder
from realmail.core.models.message import MessageResponse, MessageUpdate
from realmail.services.sync.service import sync_service

router = APIRouter(tags=["Email Sync"])


# Response models
class SyncResponse(BaseModel):
    """Sync operation response."""
    account_id: str | None = None
    folder_id: str | None = None
    folders_synced: int | None = None
    new_messages: int = 0


class PaginatedMessages(BaseModel):
    """Paginated message list."""
    items: list[MessageResponse]
    total: int
    page: int
    page_size: int


# Account sync endpoints
@router.post("/accounts/{account_id}/sync")
async def sync_account(
    account_id: str,
    full_sync: bool = False,
) -> SyncResponse:
    """Trigger sync for an account."""
    try:
        result = await sync_service.sync_account(account_id, full_sync)
        return SyncResponse(**result)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.get("/accounts/{account_id}/folders")
async def list_folders(account_id: str) -> list[FolderResponse]:
    """List folders for an account."""
    try:
        folders = await sync_service.get_folders(account_id)
        return [_folder_to_response(f) for f in folders]
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# Folder endpoints
@router.post("/folders/{folder_id}/sync")
async def sync_folder(
    folder_id: str,
    full_sync: bool = False,
) -> SyncResponse:
    """Sync a specific folder."""
    try:
        result = await sync_service.sync_folder(folder_id, full_sync)
        return SyncResponse(**result)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.get("/folders/{folder_id}/messages")
async def list_messages(
    folder_id: str,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 50,
) -> PaginatedMessages:
    """List messages in a folder."""
    try:
        offset = (page - 1) * page_size
        messages = await sync_service.get_messages(folder_id, page_size, offset)

        # Get total count
        from realmail.services.sync.repository import message_repository
        total = await message_repository.count_by_folder(folder_id)

        return PaginatedMessages(
            items=messages,
            total=total,
            page=page,
            page_size=page_size,
        )
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# Message endpoints
@router.get("/messages/{message_id}")
async def get_message(message_id: str) -> MessageResponse:
    """Get a message with full body."""
    try:
        return await sync_service.get_message(message_id)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.get("/messages/{message_id}/thread")
async def get_thread(message_id: str) -> list[MessageResponse]:
    """Get all messages in a thread."""
    try:
        return await sync_service.get_thread(message_id)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.patch("/messages/{message_id}")
async def update_message(
    message_id: str,
    update: MessageUpdate,
) -> MessageResponse:
    """Update message flags."""
    try:
        return await sync_service.update_flags(
            message_id,
            is_read=update.is_read,
            is_starred=update.is_starred,
        )
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


def _folder_to_response(folder: Folder) -> FolderResponse:
    """Convert Folder to FolderResponse."""
    return FolderResponse(
        id=folder.id,
        name=folder.name,
        full_path=folder.full_path,
        folder_type=folder.folder_type,
        is_system=folder.is_system,
        parent_id=folder.parent_id,
        message_count=folder.message_count,
        unread_count=folder.unread_count,
        children=[],
    )
