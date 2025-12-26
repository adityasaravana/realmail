"""Send queue for reliable message delivery."""

import asyncio
import json
from datetime import datetime, timezone
from enum import Enum
from typing import Any

from pydantic import BaseModel

from realmail.core.cache import get_redis
from realmail.core.logging import get_logger

logger = get_logger(__name__)


class SendStatus(str, Enum):
    """Message send status."""

    QUEUED = "queued"
    SENDING = "sending"
    SENT = "sent"
    FAILED = "failed"
    RETRYING = "retrying"


class QueuedMessage(BaseModel):
    """Message in the send queue."""

    id: str
    account_id: str
    message_bytes: str  # Base64 encoded
    from_address: str
    to_addresses: list[str]
    cc_addresses: list[str] = []
    bcc_addresses: list[str] = []
    status: SendStatus = SendStatus.QUEUED
    attempts: int = 0
    max_attempts: int = 3
    error: str | None = None
    created_at: str
    updated_at: str


class SendQueue:
    """Redis-backed send queue."""

    QUEUE_KEY = "realmail:send_queue"
    STATUS_KEY = "realmail:send_status:{id}"

    async def enqueue(
        self,
        message_id: str,
        account_id: str,
        message_bytes: bytes,
        from_address: str,
        to_addresses: list[str],
        cc_addresses: list[str] | None = None,
        bcc_addresses: list[str] | None = None,
    ) -> QueuedMessage:
        """Add message to send queue."""
        import base64

        now = datetime.now(timezone.utc).isoformat()

        queued = QueuedMessage(
            id=message_id,
            account_id=account_id,
            message_bytes=base64.b64encode(message_bytes).decode(),
            from_address=from_address,
            to_addresses=to_addresses,
            cc_addresses=cc_addresses or [],
            bcc_addresses=bcc_addresses or [],
            status=SendStatus.QUEUED,
            created_at=now,
            updated_at=now,
        )

        redis = get_redis()
        # Add to queue
        await redis.lpush(self.QUEUE_KEY, message_id)
        # Store message data
        await redis.set(
            self.STATUS_KEY.format(id=message_id),
            queued.model_dump_json(),
            ex=86400,  # 24 hour TTL
        )

        logger.info(f"Enqueued message {message_id}")
        return queued

    async def dequeue(self) -> QueuedMessage | None:
        """Get next message from queue."""
        redis = get_redis()

        # Blocking pop with 1 second timeout
        result = await redis.brpop(self.QUEUE_KEY, timeout=1)
        if not result:
            return None

        message_id = result[1]
        data = await redis.get(self.STATUS_KEY.format(id=message_id))
        if not data:
            return None

        return QueuedMessage.model_validate_json(data)

    async def update_status(
        self,
        message_id: str,
        status: SendStatus,
        error: str | None = None,
    ) -> None:
        """Update message status."""
        redis = get_redis()
        key = self.STATUS_KEY.format(id=message_id)

        data = await redis.get(key)
        if not data:
            return

        queued = QueuedMessage.model_validate_json(data)
        queued.status = status
        queued.updated_at = datetime.now(timezone.utc).isoformat()

        if error:
            queued.error = error

        if status == SendStatus.RETRYING:
            queued.attempts += 1

        await redis.set(key, queued.model_dump_json(), ex=86400)

    async def requeue(self, message_id: str) -> bool:
        """Requeue a message for retry."""
        redis = get_redis()
        key = self.STATUS_KEY.format(id=message_id)

        data = await redis.get(key)
        if not data:
            return False

        queued = QueuedMessage.model_validate_json(data)
        if queued.attempts >= queued.max_attempts:
            await self.update_status(message_id, SendStatus.FAILED, "Max retries exceeded")
            return False

        await self.update_status(message_id, SendStatus.RETRYING)
        await redis.lpush(self.QUEUE_KEY, message_id)
        return True

    async def get_status(self, message_id: str) -> QueuedMessage | None:
        """Get message status."""
        redis = get_redis()
        data = await redis.get(self.STATUS_KEY.format(id=message_id))
        if not data:
            return None
        return QueuedMessage.model_validate_json(data)


# Default instance
send_queue = SendQueue()


class QueueWorker:
    """Background worker for processing send queue."""

    def __init__(self) -> None:
        self._running = False
        self._task: asyncio.Task | None = None

    async def process_message(self, queued: QueuedMessage) -> bool:
        """Process a single queued message."""
        from realmail.services.send.service import send_service

        try:
            await send_queue.update_status(queued.id, SendStatus.SENDING)

            # Actually send the message
            import base64
            message_bytes = base64.b64decode(queued.message_bytes)

            result = await send_service.send_raw(
                queued.account_id,
                message_bytes,
                queued.from_address,
                queued.to_addresses + queued.cc_addresses + queued.bcc_addresses,
            )

            if result.get("success"):
                await send_queue.update_status(queued.id, SendStatus.SENT)
                return True
            else:
                error = result.get("error", "Unknown error")
                await send_queue.update_status(queued.id, SendStatus.FAILED, error)
                return False

        except Exception as e:
            logger.error(f"Error processing message {queued.id}: {e}")
            await send_queue.requeue(queued.id)
            return False

    async def run(self) -> None:
        """Run the queue worker loop."""
        self._running = True
        logger.info("Send queue worker started")

        while self._running:
            try:
                queued = await send_queue.dequeue()
                if queued:
                    await self.process_message(queued)
            except Exception as e:
                logger.error(f"Queue worker error: {e}")
                await asyncio.sleep(1)

        logger.info("Send queue worker stopped")

    def start(self) -> None:
        """Start the worker in background."""
        if self._task is None or self._task.done():
            self._task = asyncio.create_task(self.run())

    def stop(self) -> None:
        """Stop the worker."""
        self._running = False
        if self._task:
            self._task.cancel()


queue_worker = QueueWorker()
