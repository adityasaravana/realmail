"""FastAPI router for send endpoints."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, UploadFile, File, status
from pydantic import BaseModel, EmailStr, Field

from realmail.core.exceptions import RecordNotFoundError, AttachmentTooLargeError
from realmail.services.send.drafts import Draft, DraftCreate, DraftUpdate
from realmail.services.send.service import send_service

router = APIRouter(tags=["Email Send"])


# Request/Response models
class SendMessageRequest(BaseModel):
    """Request to send a new message."""

    account_id: str
    to_addresses: list[EmailStr] = Field(min_length=1)
    subject: str
    body_plain: str | None = None
    body_html: str | None = None
    cc_addresses: list[EmailStr] = Field(default_factory=list)
    bcc_addresses: list[EmailStr] = Field(default_factory=list)
    attachments: list[dict] = Field(default_factory=list)


class SendResponse(BaseModel):
    """Send operation response."""

    message_id: str
    status: str


class ReplyRequest(BaseModel):
    """Request to reply to a message."""

    body_plain: str | None = None
    body_html: str | None = None
    reply_all: bool = False
    attachments: list[dict] = Field(default_factory=list)


class ForwardRequest(BaseModel):
    """Request to forward a message."""

    to_addresses: list[EmailStr] = Field(min_length=1)
    body_plain: str | None = None
    body_html: str | None = None
    include_attachments: bool = True


class SendStatusResponse(BaseModel):
    """Send status response."""

    message_id: str | None = None
    status: str
    attempts: int = 0
    error: str | None = None
    created_at: str | None = None
    updated_at: str | None = None


# Send endpoints
@router.post("/messages", status_code=status.HTTP_202_ACCEPTED)
async def send_message(request: SendMessageRequest) -> SendResponse:
    """Send a new email message."""
    try:
        result = await send_service.send_message(
            account_id=request.account_id,
            to_addresses=[str(a) for a in request.to_addresses],
            subject=request.subject,
            body_plain=request.body_plain,
            body_html=request.body_html,
            cc_addresses=[str(a) for a in request.cc_addresses],
            bcc_addresses=[str(a) for a in request.bcc_addresses],
            attachments=request.attachments,
        )
        return SendResponse(**result)
    except AttachmentTooLargeError as e:
        raise HTTPException(status_code=413, detail=str(e)) from e
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.get("/messages/{message_id}/status")
async def get_send_status(message_id: str) -> SendStatusResponse:
    """Get status of a sent message."""
    result = await send_service.get_send_status(message_id)
    return SendStatusResponse(**result)


@router.post("/messages/{message_id}/reply", status_code=status.HTTP_202_ACCEPTED)
async def reply_to_message(
    message_id: str,
    account_id: str,
    request: ReplyRequest,
) -> SendResponse:
    """Reply to an existing message."""
    try:
        result = await send_service.send_reply(
            account_id=account_id,
            message_id=message_id,
            body_plain=request.body_plain,
            body_html=request.body_html,
            reply_all=request.reply_all,
            attachments=request.attachments,
        )
        return SendResponse(**result)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.post("/messages/{message_id}/forward", status_code=status.HTTP_202_ACCEPTED)
async def forward_message(
    message_id: str,
    account_id: str,
    request: ForwardRequest,
) -> SendResponse:
    """Forward an existing message."""
    try:
        result = await send_service.send_forward(
            account_id=account_id,
            message_id=message_id,
            to_addresses=[str(a) for a in request.to_addresses],
            body_plain=request.body_plain,
            body_html=request.body_html,
            include_attachments=request.include_attachments,
        )
        return SendResponse(**result)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# Draft endpoints
@router.post("/drafts", status_code=status.HTTP_201_CREATED)
async def create_draft(account_id: str, request: DraftCreate) -> Draft:
    """Create a new draft."""
    try:
        return await send_service.create_draft(account_id, request)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.get("/drafts")
async def list_drafts(account_id: str) -> list[Draft]:
    """List drafts for an account."""
    return await send_service.list_drafts(account_id)


@router.get("/drafts/{draft_id}")
async def get_draft(draft_id: str) -> Draft:
    """Get a draft."""
    try:
        return await send_service.get_draft(draft_id)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.put("/drafts/{draft_id}")
async def update_draft(draft_id: str, request: DraftUpdate) -> Draft:
    """Update a draft."""
    try:
        return await send_service.update_draft(draft_id, request)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.delete("/drafts/{draft_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_draft(draft_id: str) -> None:
    """Delete a draft."""
    deleted = await send_service.delete_draft(draft_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Draft not found")


@router.post("/drafts/{draft_id}/send", status_code=status.HTTP_202_ACCEPTED)
async def send_draft(draft_id: str) -> SendResponse:
    """Send a draft."""
    try:
        result = await send_service.send_draft(draft_id)
        return SendResponse(**result)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
