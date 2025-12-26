"""Async SMTP client wrapper."""

import base64
from email.message import EmailMessage
from typing import Any

import aiosmtplib

from realmail.core.exceptions import SMTPError
from realmail.core.logging import get_logger
from realmail.core.models.account import Account, AuthType, SecurityType

logger = get_logger(__name__)


class SMTPClient:
    """Async SMTP client with authentication support."""

    def __init__(self, account: Account) -> None:
        self.account = account
        self._client: aiosmtplib.SMTP | None = None

    async def connect(self, credentials: dict[str, Any]) -> None:
        """Establish SMTP connection."""
        try:
            host = self.account.smtp_host
            port = self.account.smtp_port
            security = SecurityType(self.account.smtp_security)

            # Determine TLS settings
            use_tls = security == SecurityType.SSL
            start_tls = security == SecurityType.STARTTLS

            self._client = aiosmtplib.SMTP(
                hostname=host,
                port=port,
                use_tls=use_tls,
                start_tls=start_tls,
                timeout=30,
            )

            await self._client.connect()

            # Authenticate
            auth_type = AuthType(self.account.auth_type)
            if auth_type == AuthType.OAUTH2:
                await self._authenticate_oauth(credentials)
            else:
                await self._authenticate_password(credentials)

            logger.info(f"Connected to SMTP: {host}")

        except Exception as e:
            logger.error(f"SMTP connection failed: {e}")
            raise SMTPError("connect", str(e), e) from e

    async def _authenticate_oauth(self, credentials: dict[str, Any]) -> None:
        """Authenticate with OAuth2 XOAUTH2."""
        access_token = credentials.get("access_token")
        if not access_token:
            raise SMTPError("auth", "No access token")

        # Build XOAUTH2 string
        email = self.account.email
        auth_string = f"user={email}\x01auth=Bearer {access_token}\x01\x01"
        auth_b64 = base64.b64encode(auth_string.encode()).decode()

        try:
            code, message = await self._client.command("AUTH XOAUTH2 " + auth_b64)
            if code not in (235, 334):
                raise SMTPError("auth", f"XOAUTH2 failed: {message}")
        except aiosmtplib.SMTPAuthenticationError as e:
            raise SMTPError("auth", f"XOAUTH2 authentication failed: {e}") from e

    async def _authenticate_password(self, credentials: dict[str, Any]) -> None:
        """Authenticate with username/password."""
        password = credentials.get("password")
        if not password:
            raise SMTPError("auth", "No password")

        try:
            await self._client.login(self.account.email, password)
        except aiosmtplib.SMTPAuthenticationError as e:
            raise SMTPError("auth", f"Login failed: {e}") from e

    async def disconnect(self) -> None:
        """Close SMTP connection."""
        if self._client:
            try:
                await self._client.quit()
            except Exception:
                pass
            self._client = None

    async def send(
        self,
        message: EmailMessage | bytes,
        from_addr: str,
        to_addrs: list[str],
    ) -> dict[str, Any]:
        """Send an email message."""
        if not self._client:
            raise SMTPError("send", "Not connected")

        try:
            if isinstance(message, bytes):
                message_str = message.decode("utf-8")
            elif isinstance(message, EmailMessage):
                message_str = message.as_string()
            else:
                message_str = str(message)

            # Send the message
            errors, response = await self._client.sendmail(
                from_addr,
                to_addrs,
                message_str,
            )

            if errors:
                logger.warning(f"Some recipients failed: {errors}")

            return {
                "success": True,
                "response": response,
                "failed_recipients": errors,
            }

        except aiosmtplib.SMTPRecipientsRefused as e:
            raise SMTPError("send", f"All recipients refused: {e}") from e
        except aiosmtplib.SMTPException as e:
            raise SMTPError("send", f"Send failed: {e}") from e

    async def verify_connection(self) -> bool:
        """Verify SMTP connection is alive."""
        if not self._client:
            return False
        try:
            await self._client.noop()
            return True
        except Exception:
            return False
