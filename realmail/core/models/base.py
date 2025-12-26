"""Base model configuration."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class RealMailModel(BaseModel):
    """Base model with common configuration."""

    model_config = ConfigDict(
        from_attributes=True,
        str_strip_whitespace=True,
        validate_assignment=True,
        populate_by_name=True,
    )


class TimestampMixin(BaseModel):
    """Mixin for created_at and updated_at fields."""

    created_at: datetime | None = None
    updated_at: datetime | None = None


def to_camel(string: str) -> str:
    """Convert snake_case to camelCase."""
    components = string.split("_")
    return components[0] + "".join(x.title() for x in components[1:])


class CamelModel(RealMailModel):
    """Model with camelCase JSON aliases."""

    model_config = ConfigDict(
        from_attributes=True,
        str_strip_whitespace=True,
        alias_generator=to_camel,
        populate_by_name=True,
    )
