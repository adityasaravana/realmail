"""Async IMAP client wrapper."""

import asyncio
import ssl
from typing import Any

from aioimaplib import IMAP4_SSL, IMAP4

from realmail.core.exceptions import IMAPError
from realmail.core.logging import get_logger
from realmail.core.models.account import Account, AuthType, SecurityType

logger = get_logger(__name__)


class IMAPClient:
    """Async IMAP client with connection management."""

    def __init__(self, account: Account) -> None:
        self.account = account
        self._client: IMAP4_SSL | IMAP4 | None = None
        self._connected = False

    @property
    def is_connected(self) -> bool:
        return self._connected and self._client is not None

    async def connect(self, credentials: dict[str, Any]) -> None:
        """Establish IMAP connection."""
        try:
            host = self.account.imap_host
            port = self.account.imap_port
            security = SecurityType(self.account.imap_security)

            if security == SecurityType.SSL:
                self._client = IMAP4_SSL(host=host, port=port)
            else:
                self._client = IMAP4(host=host, port=port)

            await self._client.wait_hello_from_server()

            if security == SecurityType.STARTTLS:
                await self._client.starttls()

            # Authenticate
            auth_type = AuthType(self.account.auth_type)
            if auth_type == AuthType.OAUTH2:
                await self._authenticate_oauth(credentials)
            else:
                await self._authenticate_password(credentials)

            self._connected = True
            logger.info(f"Connected to IMAP: {host}")

        except Exception as e:
            logger.error(f"IMAP connection failed: {e}")
            raise IMAPError("connect", str(e), e) from e

    async def _authenticate_oauth(self, credentials: dict[str, Any]) -> None:
        """Authenticate with OAuth2 XOAUTH2."""
        access_token = credentials.get("access_token")
        if not access_token:
            raise IMAPError("auth", "No access token")

        # Build XOAUTH2 string
        email = self.account.email
        auth_string = f"user={email}\x01auth=Bearer {access_token}\x01\x01"

        response = await self._client.authenticate("XOAUTH2", lambda x: auth_string)
        if response.result != "OK":
            raise IMAPError("auth", f"XOAUTH2 failed: {response.lines}")

    async def _authenticate_password(self, credentials: dict[str, Any]) -> None:
        """Authenticate with username/password."""
        password = credentials.get("password")
        if not password:
            raise IMAPError("auth", "No password")

        response = await self._client.login(self.account.email, password)
        if response.result != "OK":
            raise IMAPError("auth", f"Login failed: {response.lines}")

    async def disconnect(self) -> None:
        """Close IMAP connection."""
        if self._client:
            try:
                await self._client.logout()
            except Exception:
                pass
            self._client = None
            self._connected = False

    async def list_folders(self) -> list[dict[str, Any]]:
        """List all folders/mailboxes."""
        if not self.is_connected:
            raise IMAPError("list", "Not connected")

        response = await self._client.list('""', "*")
        if response.result != "OK":
            raise IMAPError("list", f"LIST failed: {response.lines}")

        folders = []
        for line in response.lines:
            if not line:
                continue
            parsed = self._parse_list_response(line)
            if parsed:
                folders.append(parsed)

        return folders

    def _parse_list_response(self, line: str | bytes) -> dict[str, Any] | None:
        """Parse IMAP LIST response line."""
        if isinstance(line, bytes):
            line = line.decode("utf-8", errors="replace")

        # Format: (\Flags) "delimiter" "mailbox"
        import re
        match = re.match(r'\(([^)]*)\)\s+"([^"]*)"\s+"?([^"]+)"?', line)
        if not match:
            # Try without quotes
            match = re.match(r'\(([^)]*)\)\s+(\S+)\s+(.+)', line)
        if not match:
            return None

        flags, delimiter, name = match.groups()
        flags = flags.split() if flags else []

        # Clean up name
        name = name.strip().strip('"')

        return {
            "name": name.split(delimiter)[-1] if delimiter else name,
            "full_path": name,
            "delimiter": delimiter,
            "flags": flags,
        }

    async def select_folder(self, folder: str) -> dict[str, Any]:
        """Select a folder and get its status."""
        if not self.is_connected:
            raise IMAPError("select", "Not connected")

        response = await self._client.select(folder)
        if response.result != "OK":
            raise IMAPError("select", f"SELECT failed: {response.lines}")

        # Parse response for UIDVALIDITY and EXISTS
        status = {"exists": 0, "uidvalidity": None, "uidnext": None}

        for line in response.lines:
            if isinstance(line, bytes):
                line = line.decode("utf-8", errors="replace")
            if "EXISTS" in line:
                import re
                match = re.search(r"(\d+)\s+EXISTS", line)
                if match:
                    status["exists"] = int(match.group(1))
            elif "UIDVALIDITY" in line:
                match = re.search(r"UIDVALIDITY\s+(\d+)", line)
                if match:
                    status["uidvalidity"] = int(match.group(1))
            elif "UIDNEXT" in line:
                match = re.search(r"UIDNEXT\s+(\d+)", line)
                if match:
                    status["uidnext"] = int(match.group(1))

        return status

    async def fetch_uids(self, folder: str, since_uid: int = 0) -> list[int]:
        """Fetch message UIDs in a folder."""
        await self.select_folder(folder)

        if since_uid > 0:
            search_criteria = f"UID {since_uid + 1}:*"
        else:
            search_criteria = "ALL"

        response = await self._client.uid_search(search_criteria)
        if response.result != "OK":
            raise IMAPError("search", f"UID SEARCH failed: {response.lines}")

        uids = []
        for line in response.lines:
            if isinstance(line, bytes):
                line = line.decode("utf-8", errors="replace")
            if line:
                uids.extend(int(u) for u in line.split() if u.isdigit())

        return sorted(uids)

    async def fetch_message(self, folder: str, uid: int) -> bytes | None:
        """Fetch full message by UID."""
        await self.select_folder(folder)

        response = await self._client.uid("FETCH", str(uid), "(RFC822)")
        if response.result != "OK":
            raise IMAPError("fetch", f"FETCH failed: {response.lines}")

        for line in response.lines:
            if isinstance(line, tuple):
                # Message content is in second element
                return line[1] if len(line) > 1 else None
            elif isinstance(line, bytes) and b"RFC822" in line:
                continue

        return None

    async def fetch_headers(self, folder: str, uid: int) -> bytes | None:
        """Fetch message headers only."""
        await self.select_folder(folder)

        response = await self._client.uid("FETCH", str(uid), "(RFC822.HEADER)")
        if response.result != "OK":
            raise IMAPError("fetch", f"FETCH failed: {response.lines}")

        for line in response.lines:
            if isinstance(line, tuple) and len(line) > 1:
                return line[1]

        return None

    async def fetch_flags(self, folder: str, uid: int) -> list[str]:
        """Fetch message flags."""
        await self.select_folder(folder)

        response = await self._client.uid("FETCH", str(uid), "(FLAGS)")
        if response.result != "OK":
            return []

        import re
        for line in response.lines:
            if isinstance(line, bytes):
                line = line.decode("utf-8", errors="replace")
            match = re.search(r"FLAGS\s*\(([^)]*)\)", line)
            if match:
                return match.group(1).split()

        return []

    async def set_flags(self, folder: str, uid: int, flags: list[str], add: bool = True) -> None:
        """Set or remove message flags."""
        await self.select_folder(folder)

        action = "+FLAGS" if add else "-FLAGS"
        flag_str = " ".join(flags)

        response = await self._client.uid("STORE", str(uid), action, f"({flag_str})")
        if response.result != "OK":
            raise IMAPError("store", f"STORE failed: {response.lines}")

    async def append_message(self, folder: str, message: bytes, flags: list[str] | None = None) -> int | None:
        """Append a message to a folder. Returns UID if available."""
        if not self.is_connected:
            raise IMAPError("append", "Not connected")

        flag_str = f"({' '.join(flags)})" if flags else "()"

        response = await self._client.append(folder, flag_str, None, message)
        if response.result != "OK":
            raise IMAPError("append", f"APPEND failed: {response.lines}")

        # Try to extract UID from response
        import re
        for line in response.lines:
            if isinstance(line, bytes):
                line = line.decode("utf-8", errors="replace")
            match = re.search(r"APPENDUID\s+\d+\s+(\d+)", line)
            if match:
                return int(match.group(1))

        return None

    async def idle(self, timeout: int = 29 * 60) -> list[str]:
        """Start IDLE mode to wait for notifications."""
        if not self.is_connected:
            raise IMAPError("idle", "Not connected")

        # aioimaplib doesn't have built-in IDLE support
        # This is a placeholder - would need custom implementation
        await asyncio.sleep(timeout)
        return []
