"""Email message composition."""

from email.message import EmailMessage
from typing import Any

from realmail.core.mime import build_mime_message, generate_message_id
from realmail.core.models.attachment import AttachmentCreate
from realmail.core.models.message import EmailAddress, Message


class MessageComposer:
    """Composes email messages for sending."""

    def compose(
        self,
        from_address: EmailAddress,
        to_addresses: list[EmailAddress],
        subject: str,
        body_plain: str | None = None,
        body_html: str | None = None,
        cc_addresses: list[EmailAddress] | None = None,
        bcc_addresses: list[EmailAddress] | None = None,
        reply_to: EmailAddress | None = None,
        attachments: list[AttachmentCreate] | None = None,
        in_reply_to: str | None = None,
        references: list[str] | None = None,
    ) -> EmailMessage:
        """Compose a new email message."""
        return build_mime_message(
            from_address=from_address,
            to_addresses=to_addresses,
            subject=subject,
            body_plain=body_plain,
            body_html=body_html,
            cc_addresses=cc_addresses,
            bcc_addresses=bcc_addresses,
            reply_to=reply_to,
            in_reply_to=in_reply_to,
            references=references,
            attachments=attachments,
        )

    def compose_reply(
        self,
        original: Message,
        from_address: EmailAddress,
        body_plain: str | None = None,
        body_html: str | None = None,
        reply_all: bool = False,
        attachments: list[AttachmentCreate] | None = None,
    ) -> EmailMessage:
        """Compose a reply to a message."""
        # Determine recipients
        to_addresses = [EmailAddress(address=original.from_address, name=original.from_name)]

        cc_addresses = []
        if reply_all:
            # Add original To/CC excluding ourselves
            for addr in original.to_addresses:
                parsed = EmailAddress.parse(addr)
                if parsed.address != from_address.address:
                    to_addresses.append(parsed)
            for addr in original.cc_addresses:
                parsed = EmailAddress.parse(addr)
                if parsed.address != from_address.address:
                    cc_addresses.append(parsed)

        # Build subject
        subject = original.subject or ""
        if not subject.lower().startswith("re:"):
            subject = f"Re: {subject}"

        # Build references chain
        references = list(original.references) if original.references else []
        if original.message_id and original.message_id not in references:
            references.append(original.message_id)

        # Quote original message
        quoted_plain = None
        quoted_html = None

        if body_plain:
            original_quote = self._quote_text(original.body_plain or "")
            quoted_plain = f"{body_plain}\n\n{original_quote}"

        if body_html:
            original_quote = self._quote_html(original.body_html or original.body_plain or "")
            quoted_html = f"{body_html}<br><br>{original_quote}"

        return self.compose(
            from_address=from_address,
            to_addresses=to_addresses,
            subject=subject,
            body_plain=quoted_plain or body_plain,
            body_html=quoted_html or body_html,
            cc_addresses=cc_addresses if cc_addresses else None,
            in_reply_to=original.message_id,
            references=references if references else None,
            attachments=attachments,
        )

    def compose_forward(
        self,
        original: Message,
        from_address: EmailAddress,
        to_addresses: list[EmailAddress],
        body_plain: str | None = None,
        body_html: str | None = None,
        include_attachments: bool = True,
        attachments: list[AttachmentCreate] | None = None,
    ) -> EmailMessage:
        """Compose a forward of a message."""
        # Build subject
        subject = original.subject or ""
        if not subject.lower().startswith("fwd:"):
            subject = f"Fwd: {subject}"

        # Build forwarded content
        forward_header = self._build_forward_header(original)

        if body_plain:
            forward_plain = f"{body_plain}\n\n{forward_header}\n{original.body_plain or ''}"
        else:
            forward_plain = f"{forward_header}\n{original.body_plain or ''}"

        if body_html:
            forward_html = f"{body_html}<br><br>{self._html_forward_header(original)}<br>{original.body_html or ''}"
        else:
            forward_html = None

        # TODO: Include original attachments if include_attachments is True
        all_attachments = attachments or []

        return self.compose(
            from_address=from_address,
            to_addresses=to_addresses,
            subject=subject,
            body_plain=forward_plain,
            body_html=forward_html,
            attachments=all_attachments if all_attachments else None,
        )

    def _quote_text(self, text: str) -> str:
        """Quote plain text for reply."""
        lines = text.split("\n")
        quoted = "\n".join(f"> {line}" for line in lines)
        return f"On previous message:\n{quoted}"

    def _quote_html(self, html: str) -> str:
        """Quote HTML for reply."""
        return f'<blockquote style="border-left: 2px solid #ccc; padding-left: 10px; margin-left: 0;">{html}</blockquote>'

    def _build_forward_header(self, original: Message) -> str:
        """Build forward header text."""
        return (
            "---------- Forwarded message ----------\n"
            f"From: {original.from_name or ''} <{original.from_address}>\n"
            f"Date: {original.date}\n"
            f"Subject: {original.subject or ''}\n"
            f"To: {', '.join(original.to_addresses)}\n"
        )

    def _html_forward_header(self, original: Message) -> str:
        """Build forward header HTML."""
        return (
            '<div style="border-top: 1px solid #ccc; padding-top: 10px;">'
            "<b>---------- Forwarded message ----------</b><br>"
            f"<b>From:</b> {original.from_name or ''} &lt;{original.from_address}&gt;<br>"
            f"<b>Date:</b> {original.date}<br>"
            f"<b>Subject:</b> {original.subject or ''}<br>"
            f"<b>To:</b> {', '.join(original.to_addresses)}<br>"
            "</div>"
        )


# Default instance
message_composer = MessageComposer()
