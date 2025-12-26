"""Redis cache management."""

import json
from typing import Any, TypeVar

import redis.asyncio as redis
from pydantic import BaseModel

from realmail.core.config import settings
from realmail.core.exceptions import RedisError

T = TypeVar("T", bound=BaseModel)

_redis_pool: redis.ConnectionPool | None = None
_redis_client: redis.Redis | None = None


async def init_redis() -> None:
    """Initialize Redis connection pool."""
    global _redis_pool, _redis_client
    _redis_pool = redis.ConnectionPool.from_url(
        settings.redis_url,
        max_connections=settings.redis_pool_size,
        decode_responses=True,
    )
    _redis_client = redis.Redis(connection_pool=_redis_pool)


async def close_redis() -> None:
    """Close Redis connections."""
    global _redis_pool, _redis_client
    if _redis_client:
        await _redis_client.aclose()
        _redis_client = None
    if _redis_pool:
        await _redis_pool.aclose()
        _redis_pool = None


def get_redis() -> redis.Redis:
    """Get Redis client."""
    if _redis_client is None:
        raise RedisError("get_client", "Redis not initialized")
    return _redis_client


class Cache:
    """Cache operations for Pydantic models."""

    def __init__(self, prefix: str = "realmail") -> None:
        self.prefix = prefix

    def _key(self, key: str) -> str:
        return f"{self.prefix}:{key}"

    async def get(self, key: str, model_class: type[T]) -> T | None:
        """Get a cached Pydantic model."""
        try:
            client = get_redis()
            data = await client.get(self._key(key))
            if data is None:
                return None
            return model_class.model_validate_json(data)
        except Exception as e:
            raise RedisError("get", f"Failed to get key {key}", e) from e

    async def set(
        self,
        key: str,
        model: BaseModel,
        ttl_seconds: int | None = None,
    ) -> None:
        """Cache a Pydantic model."""
        try:
            client = get_redis()
            data = model.model_dump_json()
            if ttl_seconds:
                await client.setex(self._key(key), ttl_seconds, data)
            else:
                await client.set(self._key(key), data)
        except Exception as e:
            raise RedisError("set", f"Failed to set key {key}", e) from e

    async def delete(self, key: str) -> bool:
        """Delete a cached key."""
        try:
            client = get_redis()
            result = await client.delete(self._key(key))
            return result > 0
        except Exception as e:
            raise RedisError("delete", f"Failed to delete key {key}", e) from e

    async def get_json(self, key: str) -> Any | None:
        """Get raw JSON data."""
        try:
            client = get_redis()
            data = await client.get(self._key(key))
            return json.loads(data) if data else None
        except Exception as e:
            raise RedisError("get_json", f"Failed to get key {key}", e) from e

    async def set_json(
        self,
        key: str,
        data: Any,
        ttl_seconds: int | None = None,
    ) -> None:
        """Cache raw JSON data."""
        try:
            client = get_redis()
            json_data = json.dumps(data)
            if ttl_seconds:
                await client.setex(self._key(key), ttl_seconds, json_data)
            else:
                await client.set(self._key(key), json_data)
        except Exception as e:
            raise RedisError("set_json", f"Failed to set key {key}", e) from e

    async def exists(self, key: str) -> bool:
        """Check if key exists."""
        try:
            client = get_redis()
            return await client.exists(self._key(key)) > 0
        except Exception as e:
            raise RedisError("exists", f"Failed to check key {key}", e) from e


# Default cache instance
cache = Cache()


# Pub/Sub for real-time events
class PubSub:
    """Redis Pub/Sub for event distribution."""

    def __init__(self, prefix: str = "realmail:events") -> None:
        self.prefix = prefix

    def _channel(self, channel: str) -> str:
        return f"{self.prefix}:{channel}"

    async def publish(self, channel: str, message: dict[str, Any]) -> int:
        """Publish message to channel."""
        try:
            client = get_redis()
            return await client.publish(self._channel(channel), json.dumps(message))
        except Exception as e:
            raise RedisError("publish", f"Failed to publish to {channel}", e) from e

    async def subscribe(self, *channels: str) -> redis.client.PubSub:
        """Subscribe to channels."""
        try:
            client = get_redis()
            pubsub = client.pubsub()
            await pubsub.subscribe(*[self._channel(c) for c in channels])
            return pubsub
        except Exception as e:
            raise RedisError("subscribe", f"Failed to subscribe", e) from e


pubsub = PubSub()
