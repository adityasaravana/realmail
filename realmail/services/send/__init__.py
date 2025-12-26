"""Email sending service."""

from realmail.services.send.smtp_client import SMTPClient
from realmail.services.send.composer import MessageComposer
from realmail.services.send.drafts import DraftService
from realmail.services.send.router import router as send_router
from realmail.services.send.service import SendService

__all__ = [
    "send_router",
    "SendService",
    "SMTPClient",
    "MessageComposer",
    "DraftService",
]
