"""FastAPI router for authentication endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, EmailStr, Field

from realmail.core.exceptions import AuthError, RecordNotFoundError
from realmail.core.models.account import AccountResponse, Provider, SecurityType
from realmail.services.auth.oauth import google_oauth, microsoft_oauth
from realmail.services.auth.service import auth_service

router = APIRouter(prefix="/auth", tags=["Authentication"])


# Request/Response models
class AccountCreateRequest(BaseModel):
    """Request to create account with password."""

    email: EmailStr
    password: str = Field(min_length=1)
    imap_host: str
    imap_port: int = Field(default=993, ge=1, le=65535)
    imap_security: SecurityType = SecurityType.SSL
    smtp_host: str | None = None
    smtp_port: int = Field(default=587, ge=1, le=65535)
    smtp_security: SecurityType = SecurityType.STARTTLS
    display_name: str | None = None


class VerifyResponse(BaseModel):
    """Account verification response."""

    imap: dict[str, bool | str | None]
    smtp: dict[str, bool | str | None]


# OAuth endpoints
@router.get("/google")
async def google_auth_start() -> RedirectResponse:
    """Start Google OAuth flow."""
    url = google_oauth.get_authorization_url()
    return RedirectResponse(url=url)


@router.get("/google/callback")
async def google_auth_callback(
    code: Annotated[str, Query()],
    state: Annotated[str, Query()],
) -> AccountResponse:
    """Handle Google OAuth callback."""
    try:
        return await auth_service.create_account_from_oauth(
            Provider.GMAIL, code, state
        )
    except AuthError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.get("/microsoft")
async def microsoft_auth_start() -> RedirectResponse:
    """Start Microsoft OAuth flow."""
    url = microsoft_oauth.get_authorization_url()
    return RedirectResponse(url=url)


@router.get("/microsoft/callback")
async def microsoft_auth_callback(
    code: Annotated[str, Query()],
    state: Annotated[str, Query()],
) -> AccountResponse:
    """Handle Microsoft OAuth callback."""
    try:
        return await auth_service.create_account_from_oauth(
            Provider.OUTLOOK, code, state
        )
    except AuthError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


# Account management endpoints
@router.post("/accounts", status_code=status.HTTP_201_CREATED)
async def create_account(request: AccountCreateRequest) -> AccountResponse:
    """Create account with password credentials."""
    try:
        return await auth_service.create_account_with_password(
            email=request.email,
            password=request.password,
            imap_host=request.imap_host,
            imap_port=request.imap_port,
            imap_security=request.imap_security,
            smtp_host=request.smtp_host,
            smtp_port=request.smtp_port,
            smtp_security=request.smtp_security,
            display_name=request.display_name,
        )
    except AuthError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.get("/accounts")
async def list_accounts() -> list[AccountResponse]:
    """List all accounts."""
    return await auth_service.list_accounts()


@router.get("/accounts/{account_id}")
async def get_account(account_id: str) -> AccountResponse:
    """Get account details."""
    try:
        return await auth_service.get_account(account_id)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.delete("/accounts/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(account_id: str) -> None:
    """Delete an account."""
    try:
        deleted = await auth_service.delete_account(account_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Account not found")
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.post("/accounts/{account_id}/verify")
async def verify_account(account_id: str) -> VerifyResponse:
    """Verify account credentials."""
    try:
        result = await auth_service.verify_account(account_id)
        return VerifyResponse(**result)
    except RecordNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AuthError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
