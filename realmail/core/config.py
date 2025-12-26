"""Configuration management using Pydantic BaseSettings."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    All settings are prefixed with REALMAIL_ in environment variables.
    Example: REALMAIL_DATABASE_URL, REALMAIL_REDIS_URL
    """

    model_config = SettingsConfigDict(
        env_prefix="REALMAIL_",
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    app_name: str = "RealMail"
    debug: bool = False
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"

    # Database
    database_url: str = Field(
        default="sqlite+aiosqlite:///realmail.db",
        description="SQLite database URL",
    )

    # Redis
    redis_url: str = Field(
        default="redis://localhost:6379/0",
        description="Redis connection URL",
    )
    redis_pool_size: int = Field(default=10, ge=1, le=100)

    # Security
    secret_key: str = Field(
        default="change-me-in-production",
        min_length=16,
        description="Secret key for encryption",
    )

    # Email
    max_attachment_size_mb: int = Field(default=25, ge=1, le=100)
    sync_interval_seconds: int = Field(default=60, ge=10)

    # OAuth2
    google_client_id: str = ""
    google_client_secret: str = ""
    microsoft_client_id: str = ""
    microsoft_client_secret: str = ""
    oauth_redirect_base_url: str = "http://localhost:8000"

    @field_validator("log_level", mode="before")
    @classmethod
    def uppercase_log_level(cls, v: str) -> str:
        return v.upper() if isinstance(v, str) else v

    @property
    def max_attachment_size_bytes(self) -> int:
        return self.max_attachment_size_mb * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()
