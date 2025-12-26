"""Async SQLite database management."""

import asyncio
from contextlib import asynccontextmanager
from typing import AsyncGenerator

import aiosqlite

from realmail.core.config import settings
from realmail.core.exceptions import DatabaseConnectionError

# Connection pool
_connection_pool: list[aiosqlite.Connection] = []
_pool_lock = asyncio.Lock()
_pool_size = 5


async def init_database() -> None:
    """Initialize database and create tables."""
    async with get_connection() as conn:
        await conn.executescript(DATABASE_SCHEMA)
        await conn.commit()


async def close_database() -> None:
    """Close all database connections."""
    async with _pool_lock:
        for conn in _connection_pool:
            await conn.close()
        _connection_pool.clear()


@asynccontextmanager
async def get_connection() -> AsyncGenerator[aiosqlite.Connection, None]:
    """Get a database connection from the pool."""
    conn: aiosqlite.Connection | None = None

    async with _pool_lock:
        if _connection_pool:
            conn = _connection_pool.pop()

    if conn is None:
        try:
            db_path = settings.database_url.replace("sqlite+aiosqlite:///", "")
            conn = await aiosqlite.connect(db_path)
            conn.row_factory = aiosqlite.Row
        except Exception as e:
            raise DatabaseConnectionError(f"Failed to connect: {e}") from e

    try:
        yield conn
    finally:
        async with _pool_lock:
            if len(_connection_pool) < _pool_size:
                _connection_pool.append(conn)
            else:
                await conn.close()


DATABASE_SCHEMA = """
-- Accounts table
CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    display_name TEXT,
    provider TEXT NOT NULL,  -- gmail, outlook, imap
    imap_host TEXT NOT NULL,
    imap_port INTEGER NOT NULL DEFAULT 993,
    imap_security TEXT NOT NULL DEFAULT 'SSL',
    smtp_host TEXT NOT NULL,
    smtp_port INTEGER NOT NULL DEFAULT 587,
    smtp_security TEXT NOT NULL DEFAULT 'STARTTLS',
    auth_type TEXT NOT NULL DEFAULT 'oauth2',  -- oauth2, password
    encrypted_credentials TEXT,
    status TEXT NOT NULL DEFAULT 'active',  -- active, auth_error, connection_error, disabled
    last_sync_at TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Folders table
CREATE TABLE IF NOT EXISTS folders (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    full_path TEXT NOT NULL,
    parent_id TEXT REFERENCES folders(id) ON DELETE CASCADE,
    folder_type TEXT NOT NULL DEFAULT 'custom',  -- inbox, sent, drafts, trash, spam, archive, custom
    is_system BOOLEAN NOT NULL DEFAULT 0,
    imap_uidvalidity INTEGER,
    imap_last_uid INTEGER DEFAULT 0,
    message_count INTEGER DEFAULT 0,
    unread_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_id, full_path)
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    imap_uid INTEGER,
    message_id TEXT,  -- RFC Message-ID header
    thread_id TEXT,
    in_reply_to TEXT,
    "references" TEXT,  -- JSON array of message-ids
    from_address TEXT NOT NULL,
    from_name TEXT,
    to_addresses TEXT NOT NULL,  -- JSON array
    cc_addresses TEXT,  -- JSON array
    bcc_addresses TEXT,  -- JSON array
    reply_to TEXT,
    subject TEXT,
    date TEXT NOT NULL,
    body_plain TEXT,
    body_html TEXT,
    snippet TEXT,
    has_attachments BOOLEAN NOT NULL DEFAULT 0,
    is_read BOOLEAN NOT NULL DEFAULT 0,
    is_starred BOOLEAN NOT NULL DEFAULT 0,
    is_answered BOOLEAN NOT NULL DEFAULT 0,
    is_draft BOOLEAN NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    raw_headers TEXT,  -- JSON object
    size_bytes INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(folder_id, imap_uid)
);

-- Attachments table
CREATE TABLE IF NOT EXISTS attachments (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    content_type TEXT NOT NULL,
    content_id TEXT,  -- For inline attachments
    size_bytes INTEGER NOT NULL,
    is_inline BOOLEAN NOT NULL DEFAULT 0,
    content_base64 TEXT,  -- Stored content (may be NULL for large attachments)
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Drafts table (local drafts before IMAP sync)
CREATE TABLE IF NOT EXISTS drafts (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    to_addresses TEXT,  -- JSON array
    cc_addresses TEXT,  -- JSON array
    bcc_addresses TEXT,  -- JSON array
    subject TEXT,
    body_plain TEXT,
    body_html TEXT,
    reply_to_message_id TEXT REFERENCES messages(id),
    forward_message_id TEXT REFERENCES messages(id),
    imap_uid INTEGER,  -- UID in Drafts folder after sync
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Draft attachments
CREATE TABLE IF NOT EXISTS draft_attachments (
    id TEXT PRIMARY KEY,
    draft_id TEXT NOT NULL REFERENCES drafts(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    content_base64 TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Sync status tracking
CREATE TABLE IF NOT EXISTS sync_status (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    folder_id TEXT REFERENCES folders(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'idle',  -- idle, syncing, completed, failed
    started_at TEXT,
    completed_at TEXT,
    messages_synced INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_folders_account ON folders(account_id);
CREATE INDEX IF NOT EXISTS idx_messages_folder ON messages(folder_id);
CREATE INDEX IF NOT EXISTS idx_messages_account ON messages(account_id);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date DESC);
CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id);
CREATE INDEX IF NOT EXISTS idx_attachments_message ON attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_drafts_account ON drafts(account_id);
"""
