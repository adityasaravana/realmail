"""MIME parsing and construction utilities."""

import base64
import email
import email.utils
import quopri
import re
import uuid
from datetime import datetime, timezone
from email.header import decode_header, make_header
from email.message import EmailMessage, Message
from email.mime.application import MIMEApplication
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Any

from realmail.core.models.attachment import AttachmentCreate
from realmail.core.models.message import EmailAddress


def decode_header_value(value: str | None) -> str:
    """Decode RFC 2047 encoded header value."""
    if not value:
        return ""
    try:
        decoded = make_header(decode_header(value))
        return str(decoded)
    except Exception:
        return value


def parse_address(raw: str) -> EmailAddress:
    """Parse email address from header value."""
    name, addr = email.utils.parseaddr(raw)
    name = decode_header_value(name)
    return EmailAddress(address=addr or raw, name=name or None)


def parse_address_list(raw: str) -> list[EmailAddress]:
    """Parse list of email addresses from header value."""
    if not raw:
        return []
    addresses = email.utils.getaddresses([raw])
    result = []
    for name, addr in addresses:
        if addr:
            name = decode_header_value(name)
            result.append(EmailAddress(address=addr, name=name or None))
    return result


def parse_date(raw: str | None) -> datetime:
    """Parse email date header to datetime."""
    if not raw:
        return datetime.now(timezone.utc)
    try:
        parsed = email.utils.parsedate_to_datetime(raw)
        return parsed
    except Exception:
        return datetime.now(timezone.utc)


def generate_message_id(domain: str = "realmail.local") -> str:
    """Generate a unique Message-ID."""
    unique = uuid.uuid4().hex
    timestamp = int(datetime.now(timezone.utc).timestamp())
    return f"<{unique}.{timestamp}@{domain}>"


class ParsedMessage:
    """Parsed email message structure."""

    def __init__(self) -> None:
        self.message_id: str | None = None
        self.in_reply_to: str | None = None
        self.references: list[str] = []
        self.from_address: EmailAddress | None = None
        self.to_addresses: list[EmailAddress] = []
        self.cc_addresses: list[EmailAddress] = []
        self.bcc_addresses: list[EmailAddress] = []
        self.reply_to: EmailAddress | None = None
        self.subject: str | None = None
        self.date: datetime = datetime.now(timezone.utc)
        self.body_plain: str | None = None
        self.body_html: str | None = None
        self.attachments: list[AttachmentCreate] = []
        self.headers: dict[str, str] = {}
        self.size_bytes: int = 0


def parse_mime_message(raw_bytes: bytes) -> ParsedMessage:
    """Parse raw MIME message bytes into structured data."""
    result = ParsedMessage()
    result.size_bytes = len(raw_bytes)

    msg = email.message_from_bytes(raw_bytes)

    # Parse headers
    result.message_id = msg.get("Message-ID")
    result.in_reply_to = msg.get("In-Reply-To")

    refs = msg.get("References", "")
    if refs:
        result.references = re.findall(r"<[^>]+>", refs)

    result.subject = decode_header_value(msg.get("Subject"))
    result.date = parse_date(msg.get("Date"))

    # Parse addresses
    from_header = msg.get("From", "")
    if from_header:
        result.from_address = parse_address(from_header)

    result.to_addresses = parse_address_list(msg.get("To", ""))
    result.cc_addresses = parse_address_list(msg.get("Cc", ""))
    result.bcc_addresses = parse_address_list(msg.get("Bcc", ""))

    reply_to_header = msg.get("Reply-To", "")
    if reply_to_header:
        addrs = parse_address_list(reply_to_header)
        result.reply_to = addrs[0] if addrs else None

    # Store raw headers
    for key in msg.keys():
        result.headers[key] = decode_header_value(msg.get(key))

    # Parse body and attachments
    _parse_parts(msg, result)

    return result


def _parse_parts(msg: Message, result: ParsedMessage) -> None:
    """Recursively parse message parts."""
    if msg.is_multipart():
        for part in msg.get_payload():
            _parse_parts(part, result)
    else:
        content_type = msg.get_content_type()
        content_disposition = msg.get("Content-Disposition", "")
        filename = msg.get_filename()

        # Decode content
        payload = msg.get_payload(decode=True)
        if payload is None:
            return

        charset = msg.get_content_charset() or "utf-8"

        # Check if attachment
        if filename or "attachment" in content_disposition.lower():
            if filename:
                filename = decode_header_value(filename)
            else:
                filename = f"attachment_{len(result.attachments)}"

            content_id = msg.get("Content-ID")
            if content_id:
                content_id = content_id.strip("<>")

            result.attachments.append(
                AttachmentCreate(
                    filename=filename,
                    content_type=content_type,
                    size_bytes=len(payload),
                    content=payload,
                    content_id=content_id,
                    is_inline="inline" in content_disposition.lower(),
                )
            )
        elif content_type == "text/plain" and result.body_plain is None:
            try:
                result.body_plain = payload.decode(charset, errors="replace")
            except Exception:
                result.body_plain = payload.decode("utf-8", errors="replace")
        elif content_type == "text/html" and result.body_html is None:
            try:
                result.body_html = payload.decode(charset, errors="replace")
            except Exception:
                result.body_html = payload.decode("utf-8", errors="replace")


def build_mime_message(
    from_address: EmailAddress,
    to_addresses: list[EmailAddress],
    subject: str,
    body_plain: str | None = None,
    body_html: str | None = None,
    cc_addresses: list[EmailAddress] | None = None,
    bcc_addresses: list[EmailAddress] | None = None,
    reply_to: EmailAddress | None = None,
    in_reply_to: str | None = None,
    references: list[str] | None = None,
    attachments: list[AttachmentCreate] | None = None,
    message_id: str | None = None,
) -> EmailMessage:
    """Build a MIME message from components."""

    # Determine message structure
    has_attachments = attachments and len(attachments) > 0
    has_html = body_html is not None
    has_plain = body_plain is not None

    if has_attachments:
        msg = MIMEMultipart("mixed")
        if has_html and has_plain:
            alt = MIMEMultipart("alternative")
            alt.attach(MIMEText(body_plain, "plain", "utf-8"))
            alt.attach(MIMEText(body_html, "html", "utf-8"))
            msg.attach(alt)
        elif has_html:
            msg.attach(MIMEText(body_html, "html", "utf-8"))
        elif has_plain:
            msg.attach(MIMEText(body_plain, "plain", "utf-8"))
    elif has_html and has_plain:
        msg = MIMEMultipart("alternative")
        msg.attach(MIMEText(body_plain, "plain", "utf-8"))
        msg.attach(MIMEText(body_html, "html", "utf-8"))
    elif has_html:
        msg = MIMEText(body_html, "html", "utf-8")
    else:
        msg = MIMEText(body_plain or "", "plain", "utf-8")

    # Set headers
    msg["From"] = str(from_address)
    msg["To"] = ", ".join(str(a) for a in to_addresses)

    if cc_addresses:
        msg["Cc"] = ", ".join(str(a) for a in cc_addresses)

    # BCC is not included in headers (handled during sending)

    msg["Subject"] = subject
    msg["Date"] = email.utils.formatdate(localtime=True)
    msg["Message-ID"] = message_id or generate_message_id()

    if reply_to:
        msg["Reply-To"] = str(reply_to)

    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to

    if references:
        msg["References"] = " ".join(references)

    # Add attachments
    if attachments:
        for att in attachments:
            if att.is_inline and att.content_id:
                part = MIMEBase(*att.content_type.split("/", 1))
                part.set_payload(att.content)
                email.encoders.encode_base64(part)
                part.add_header("Content-ID", f"<{att.content_id}>")
                part.add_header(
                    "Content-Disposition", "inline", filename=att.filename
                )
            else:
                maintype, subtype = att.content_type.split("/", 1)
                if maintype == "application":
                    part = MIMEApplication(att.content, _subtype=subtype)
                else:
                    part = MIMEBase(maintype, subtype)
                    part.set_payload(att.content)
                    email.encoders.encode_base64(part)
                part.add_header(
                    "Content-Disposition", "attachment", filename=att.filename
                )
            msg.attach(part)

    return msg


def get_snippet(body_plain: str | None, body_html: str | None, max_length: int = 200) -> str:
    """Extract snippet from message body."""
    text = body_plain or ""

    if not text and body_html:
        # Strip HTML tags
        text = re.sub(r"<[^>]+>", " ", body_html)
        text = re.sub(r"\s+", " ", text).strip()

    # Truncate to max length
    if len(text) > max_length:
        text = text[:max_length].rsplit(" ", 1)[0] + "..."

    return text
