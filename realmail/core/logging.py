"""Structured logging configuration."""

import json
import logging
import sys
from contextvars import ContextVar
from datetime import datetime, timezone
from typing import Any

from realmail.core.config import settings

# Context variables for request tracking
request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)
user_id_var: ContextVar[str | None] = ContextVar("user_id", default=None)
account_id_var: ContextVar[str | None] = ContextVar("account_id", default=None)


class JsonFormatter(logging.Formatter):
    """JSON log formatter for structured logging."""

    def format(self, record: logging.LogRecord) -> str:
        log_data: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add context from context vars
        if request_id := request_id_var.get():
            log_data["request_id"] = request_id

        if user_id := user_id_var.get():
            log_data["user_id"] = user_id

        if account_id := account_id_var.get():
            log_data["account_id"] = account_id

        # Add extra fields
        if hasattr(record, "extra"):
            log_data.update(record.extra)

        # Add exception info
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        # Add location info
        if settings.debug:
            log_data["location"] = {
                "file": record.filename,
                "line": record.lineno,
                "function": record.funcName,
            }

        return json.dumps(log_data, default=str)


class ContextLogger(logging.LoggerAdapter):
    """Logger adapter that includes context in all log messages."""

    def process(
        self, msg: str, kwargs: dict[str, Any]
    ) -> tuple[str, dict[str, Any]]:
        extra = kwargs.get("extra", {})

        # Add context vars
        if request_id := request_id_var.get():
            extra["request_id"] = request_id
        if user_id := user_id_var.get():
            extra["user_id"] = user_id
        if account_id := account_id_var.get():
            extra["account_id"] = account_id

        kwargs["extra"] = extra
        return msg, kwargs


def setup_logging() -> None:
    """Configure application logging."""
    root_logger = logging.getLogger()
    root_logger.setLevel(settings.log_level)

    # Remove existing handlers
    root_logger.handlers.clear()

    # Create console handler with JSON formatting
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(settings.log_level)

    if settings.debug:
        # Use simple format in debug mode
        formatter = logging.Formatter(
            "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"
        )
    else:
        # Use JSON format in production
        formatter = JsonFormatter()

    handler.setFormatter(formatter)
    root_logger.addHandler(handler)

    # Quiet noisy loggers
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("asyncio").setLevel(logging.WARNING)


def get_logger(name: str) -> ContextLogger:
    """Get a context-aware logger."""
    logger = logging.getLogger(name)
    return ContextLogger(logger, {})


# Convenience function for setting context
def set_log_context(
    request_id: str | None = None,
    user_id: str | None = None,
    account_id: str | None = None,
) -> None:
    """Set logging context for current async context."""
    if request_id is not None:
        request_id_var.set(request_id)
    if user_id is not None:
        user_id_var.set(user_id)
    if account_id is not None:
        account_id_var.set(account_id)


def clear_log_context() -> None:
    """Clear logging context."""
    request_id_var.set(None)
    user_id_var.set(None)
    account_id_var.set(None)
