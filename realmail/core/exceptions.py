"""Custom exceptions for RealMail."""

from typing import Any


class RealMailError(Exception):
    """Base exception for all RealMail errors."""

    def __init__(
        self,
        message: str,
        code: str = "REALMAIL_ERROR",
        details: dict[str, Any] | None = None,
    ) -> None:
        self.message = message
        self.code = code
        self.details = details or {}
        super().__init__(message)

    def to_dict(self) -> dict[str, Any]:
        return {
            "error": self.code,
            "message": self.message,
            "details": self.details,
        }


# Database Exceptions
class DatabaseError(RealMailError):
    """Base database error."""

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(message, "DATABASE_ERROR", details)


class DatabaseConnectionError(DatabaseError):
    """Failed to connect to database."""

    def __init__(self, message: str = "Failed to connect to database") -> None:
        super().__init__(message)


class RecordNotFoundError(DatabaseError):
    """Record not found in database."""

    def __init__(self, entity: str, entity_id: str | int) -> None:
        super().__init__(
            f"{entity} with id '{entity_id}' not found",
            {"entity": entity, "id": str(entity_id)},
        )


# Authentication Exceptions
class AuthError(RealMailError):
    """Base authentication error."""

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(message, "AUTH_ERROR", details)


class InvalidCredentialsError(AuthError):
    """Invalid credentials provided."""

    def __init__(self, message: str = "Invalid credentials") -> None:
        super().__init__(message)


class TokenExpiredError(AuthError):
    """OAuth token has expired."""

    def __init__(self, account_id: str) -> None:
        super().__init__(
            "OAuth token has expired and refresh failed",
            {"account_id": account_id},
        )


class OAuthError(AuthError):
    """OAuth flow error."""

    def __init__(self, provider: str, message: str) -> None:
        super().__init__(message, {"provider": provider})


# Email Exceptions
class EmailError(RealMailError):
    """Base email error."""

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(message, "EMAIL_ERROR", details)


class MessageNotFoundError(EmailError):
    """Email message not found."""

    def __init__(self, message_id: str) -> None:
        super().__init__(
            f"Message '{message_id}' not found",
            {"message_id": message_id},
        )


class FolderNotFoundError(EmailError):
    """Email folder not found."""

    def __init__(self, folder_name: str) -> None:
        super().__init__(
            f"Folder '{folder_name}' not found",
            {"folder_name": folder_name},
        )


class AttachmentTooLargeError(EmailError):
    """Attachment exceeds size limit."""

    def __init__(self, size_bytes: int, max_bytes: int) -> None:
        super().__init__(
            f"Attachment size {size_bytes} exceeds maximum {max_bytes}",
            {"size_bytes": size_bytes, "max_bytes": max_bytes},
        )


# External Service Exceptions
class ExternalServiceError(RealMailError):
    """Error from external service."""

    def __init__(
        self,
        service: str,
        operation: str,
        message: str,
        original_error: Exception | None = None,
    ) -> None:
        details: dict[str, Any] = {"service": service, "operation": operation}
        if original_error:
            details["original_error"] = str(original_error)
        super().__init__(message, "EXTERNAL_SERVICE_ERROR", details)


class IMAPError(ExternalServiceError):
    """IMAP server error."""

    def __init__(self, operation: str, message: str, original: Exception | None = None) -> None:
        super().__init__("IMAP", operation, message, original)


class SMTPError(ExternalServiceError):
    """SMTP server error."""

    def __init__(self, operation: str, message: str, original: Exception | None = None) -> None:
        super().__init__("SMTP", operation, message, original)


class RedisError(ExternalServiceError):
    """Redis error."""

    def __init__(self, operation: str, message: str, original: Exception | None = None) -> None:
        super().__init__("Redis", operation, message, original)
