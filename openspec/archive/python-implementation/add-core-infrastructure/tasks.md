# Tasks: Add Core Infrastructure

## 1. Project Setup
- [ ] 1.1 Create `pyproject.toml` with dependencies (FastAPI, Pydantic, aiosqlite, redis, etc.)
- [ ] 1.2 Create package structure: `realmail/`, `realmail/core/`, `realmail/services/`
- [ ] 1.3 Set up `realmail/core/config.py` with Pydantic BaseSettings

## 2. Database Layer
- [ ] 2.1 Create `realmail/core/database.py` with async SQLite connection pool
- [ ] 2.2 Define database schema for accounts, folders, messages, attachments
- [ ] 2.3 Create `realmail/core/repositories/` base repository pattern

## 3. Shared Models
- [ ] 3.1 Create `realmail/core/models/account.py` - Account Pydantic models
- [ ] 3.2 Create `realmail/core/models/folder.py` - Folder Pydantic models
- [ ] 3.3 Create `realmail/core/models/message.py` - Message Pydantic models
- [ ] 3.4 Create `realmail/core/models/attachment.py` - Attachment Pydantic models

## 4. Redis Integration
- [ ] 4.1 Create `realmail/core/cache.py` with Redis connection management
- [ ] 4.2 Implement cache decorators for common patterns

## 5. Utilities
- [ ] 5.1 Create `realmail/core/mime.py` for MIME parsing utilities
- [ ] 5.2 Create `realmail/core/logging.py` for structured logging
- [ ] 5.3 Create `realmail/core/exceptions.py` for custom exceptions

## 6. Testing
- [ ] 6.1 Set up pytest configuration with async support
- [ ] 6.2 Create test fixtures for database and Redis
- [ ] 6.3 Write unit tests for core models
