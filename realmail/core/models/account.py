"""Account models."""

from datetime import datetime
from enum import Enum

from pydantic import EmailStr, Field

from realmail.core.models.base import RealMailModel, TimestampMixin


class Provider(str, Enum):
    """Email provider types."""

    GMAIL = "gmail"
    OUTLOOK = "outlook"
    IMAP = "imap"  # Generic IMAP


class AuthType(str, Enum):
    """Authentication types."""

    OAUTH2 = "oauth2"
    PASSWORD = "password"


class SecurityType(str, Enum):
    """Connection security types."""

    SSL = "SSL"
    STARTTLS = "STARTTLS"
    NONE = "NONE"


class AccountStatus(str, Enum):
    """Account status types."""

    ACTIVE = "active"
    AUTH_ERROR = "auth_error"
    CONNECTION_ERROR = "connection_error"
    REQUIRES_REAUTH = "requires_reauth"
    DISABLED = "disabled"


class AccountBase(RealMailModel):
    """Base account fields."""

    email: EmailStr
    display_name: str | None = None
    provider: Provider


class AccountCreate(AccountBase):
    """Account creation model."""

    # IMAP settings
    imap_host: str
    imap_port: int = Field(default=993, ge=1, le=65535)
    imap_security: SecurityType = SecurityType.SSL

    # SMTP settings
    smtp_host: str
    smtp_port: int = Field(default=587, ge=1, le=65535)
    smtp_security: SecurityType = SecurityType.STARTTLS

    # Auth
    auth_type: AuthType = AuthType.OAUTH2
    password: str | None = None  # For password auth
    oauth_access_token: str | None = None  # For OAuth
    oauth_refresh_token: str | None = None


class AccountUpdate(RealMailModel):
    """Account update model."""

    display_name: str | None = None
    status: AccountStatus | None = None


class Account(AccountBase, TimestampMixin):
    """Full account model (database representation)."""

    id: str
    imap_host: str
    imap_port: int
    imap_security: SecurityType
    smtp_host: str
    smtp_port: int
    smtp_security: SecurityType
    auth_type: AuthType
    encrypted_credentials: str | None = None
    status: AccountStatus = AccountStatus.ACTIVE
    last_sync_at: datetime | None = None
    last_error: str | None = None


class AccountResponse(RealMailModel):
    """Account response model (API output)."""

    id: str
    email: EmailStr
    display_name: str | None
    provider: Provider
    imap_host: str
    smtp_host: str
    auth_type: AuthType
    status: AccountStatus
    last_sync_at: datetime | None
    folder_count: int = 0
    unread_count: int = 0
    created_at: datetime | None


# Provider configurations
PROVIDER_CONFIGS: dict[Provider, dict[str, str | int]] = {
    Provider.GMAIL: {
        "imap_host": "imap.gmail.com",
        "imap_port": 993,
        "imap_security": "SSL",
        "smtp_host": "smtp.gmail.com",
        "smtp_port": 587,
        "smtp_security": "STARTTLS",
    },
    Provider.OUTLOOK: {
        "imap_host": "outlook.office365.com",
        "imap_port": 993,
        "imap_security": "SSL",
        "smtp_host": "smtp.office365.com",
        "smtp_port": 587,
        "smtp_security": "STARTTLS",
    },
}
