"""Base repository with common CRUD operations."""

import json
import uuid
from datetime import datetime, timezone
from typing import Any, Generic, TypeVar

import aiosqlite

from realmail.core.database import get_connection
from realmail.core.exceptions import RecordNotFoundError
from realmail.core.models.base import RealMailModel

T = TypeVar("T", bound=RealMailModel)


def generate_id() -> str:
    """Generate a unique ID."""
    return uuid.uuid4().hex


def now_iso() -> str:
    """Get current UTC time as ISO string."""
    return datetime.now(timezone.utc).isoformat()


class BaseRepository(Generic[T]):
    """Base repository with common database operations."""

    table_name: str
    model_class: type[T]

    def __init__(self) -> None:
        if not hasattr(self, "table_name"):
            raise NotImplementedError("Subclass must define table_name")
        if not hasattr(self, "model_class"):
            raise NotImplementedError("Subclass must define model_class")

    async def get_by_id(self, id: str) -> T | None:
        """Get record by ID."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                f"SELECT * FROM {self.table_name} WHERE id = ?", (id,)
            )
            row = await cursor.fetchone()
            if row:
                return self._row_to_model(row)
            return None

    async def get_by_id_or_raise(self, id: str) -> T:
        """Get record by ID or raise RecordNotFoundError."""
        record = await self.get_by_id(id)
        if record is None:
            raise RecordNotFoundError(self.table_name, id)
        return record

    async def get_all(
        self,
        limit: int = 100,
        offset: int = 0,
        order_by: str = "created_at DESC",
    ) -> list[T]:
        """Get all records with pagination."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                f"SELECT * FROM {self.table_name} ORDER BY {order_by} LIMIT ? OFFSET ?",
                (limit, offset),
            )
            rows = await cursor.fetchall()
            return [self._row_to_model(row) for row in rows]

    async def count(self, where: str = "", params: tuple = ()) -> int:
        """Count records."""
        async with get_connection() as conn:
            query = f"SELECT COUNT(*) FROM {self.table_name}"
            if where:
                query += f" WHERE {where}"
            cursor = await conn.execute(query, params)
            row = await cursor.fetchone()
            return row[0] if row else 0

    async def create(self, data: dict[str, Any]) -> T:
        """Create a new record."""
        if "id" not in data:
            data["id"] = generate_id()
        if "created_at" not in data:
            data["created_at"] = now_iso()
        if "updated_at" not in data:
            data["updated_at"] = now_iso()

        # Convert lists/dicts to JSON
        data = self._serialize_data(data)

        columns = ", ".join(data.keys())
        placeholders = ", ".join("?" for _ in data)
        values = tuple(data.values())

        async with get_connection() as conn:
            await conn.execute(
                f"INSERT INTO {self.table_name} ({columns}) VALUES ({placeholders})",
                values,
            )
            await conn.commit()

        return await self.get_by_id_or_raise(data["id"])

    async def update(self, id: str, data: dict[str, Any]) -> T:
        """Update a record."""
        data["updated_at"] = now_iso()
        data = self._serialize_data(data)

        set_clause = ", ".join(f"{k} = ?" for k in data.keys())
        values = tuple(data.values()) + (id,)

        async with get_connection() as conn:
            await conn.execute(
                f"UPDATE {self.table_name} SET {set_clause} WHERE id = ?",
                values,
            )
            await conn.commit()

        return await self.get_by_id_or_raise(id)

    async def delete(self, id: str) -> bool:
        """Delete a record."""
        async with get_connection() as conn:
            cursor = await conn.execute(
                f"DELETE FROM {self.table_name} WHERE id = ?", (id,)
            )
            await conn.commit()
            return cursor.rowcount > 0

    async def find_by(self, **kwargs: Any) -> list[T]:
        """Find records matching criteria."""
        where_parts = []
        values = []
        for key, value in kwargs.items():
            where_parts.append(f"{key} = ?")
            values.append(value)

        where_clause = " AND ".join(where_parts)

        async with get_connection() as conn:
            cursor = await conn.execute(
                f"SELECT * FROM {self.table_name} WHERE {where_clause}",
                tuple(values),
            )
            rows = await cursor.fetchall()
            return [self._row_to_model(row) for row in rows]

    async def find_one_by(self, **kwargs: Any) -> T | None:
        """Find first record matching criteria."""
        results = await self.find_by(**kwargs)
        return results[0] if results else None

    def _row_to_model(self, row: aiosqlite.Row) -> T:
        """Convert database row to model."""
        data = dict(row)
        data = self._deserialize_data(data)
        return self.model_class.model_validate(data)

    def _serialize_data(self, data: dict[str, Any]) -> dict[str, Any]:
        """Serialize complex types for storage."""
        result = {}
        for key, value in data.items():
            if isinstance(value, (list, dict)):
                result[key] = json.dumps(value)
            elif isinstance(value, datetime):
                result[key] = value.isoformat()
            elif isinstance(value, bool):
                result[key] = 1 if value else 0
            else:
                result[key] = value
        return result

    def _deserialize_data(self, data: dict[str, Any]) -> dict[str, Any]:
        """Deserialize complex types from storage."""
        result = {}
        for key, value in data.items():
            if isinstance(value, str) and value.startswith(("[", "{")):
                try:
                    result[key] = json.loads(value)
                except json.JSONDecodeError:
                    result[key] = value
            else:
                result[key] = value
        return result
