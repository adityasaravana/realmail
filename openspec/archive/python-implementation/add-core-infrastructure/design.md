# Design: Core Infrastructure

## Context
RealMail is a Python-based email client using microservices architecture. Each service needs shared models, database access, and configuration. This design establishes patterns all services will follow.

## Goals / Non-Goals
**Goals:**
- Establish consistent Pydantic model patterns across all services
- Provide async database access with connection pooling
- Create reusable Redis caching layer
- Define project structure that scales with multiple services

**Non-Goals:**
- Implement any domain-specific business logic (handled by service proposals)
- Set up deployment infrastructure (Docker, K8s, etc.)
- Implement authentication (separate proposal)

## Decisions

### 1. Package Structure
```
realmail/
├── core/                    # Shared infrastructure
│   ├── config.py           # Pydantic BaseSettings
│   ├── database.py         # Async SQLite setup
│   ├── cache.py            # Redis connection
│   ├── exceptions.py       # Custom exceptions
│   ├── logging.py          # Structured logging
│   ├── mime.py             # MIME utilities
│   ├── models/             # Shared Pydantic models
│   │   ├── account.py
│   │   ├── folder.py
│   │   ├── message.py
│   │   └── attachment.py
│   └── repositories/       # Base repository pattern
│       └── base.py
└── services/               # Individual microservices
    ├── sync/               # Email sync service
    ├── send/               # Email send service
    └── auth/               # Auth service
```

**Rationale:** Monorepo with shared `core/` package enables code reuse while maintaining service independence. Services import from `realmail.core` but don't import each other.

### 2. Database: SQLite with aiosqlite
- Use `aiosqlite` for async database operations
- Single SQLite file for simplicity; migration path to PostgreSQL documented
- Repository pattern abstracts database access

**Alternatives considered:**
- PostgreSQL directly: Overkill for initial development, adds infrastructure complexity
- SQLAlchemy ORM: Adds abstraction layer; prefer raw SQL with Pydantic for transparency

### 3. Pydantic Model Patterns
```python
# Base model with common config
class RealMailModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        str_strip_whitespace=True,
    )

# Schema variants
class MessageCreate(RealMailModel): ...  # Input for creation
class MessageUpdate(RealMailModel): ...  # Partial update fields
class MessageResponse(RealMailModel): ... # API response
class MessageDB(RealMailModel): ...       # Database representation
```

### 4. Configuration via Environment
```python
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="REALMAIL_")

    database_url: str = "sqlite+aiosqlite:///realmail.db"
    redis_url: str = "redis://localhost:6379"
    log_level: str = "INFO"
```

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| SQLite concurrency limits | Medium | Document PostgreSQL migration; design with DB abstraction |
| Monorepo coupling | Low | Enforce import boundaries via linting rules |
| Model proliferation | Medium | Use base classes; document naming conventions |

## Migration Plan
1. No migration needed (greenfield project)
2. For SQLite → PostgreSQL: Replace aiosqlite with asyncpg, update connection strings

## Open Questions
- Should we use Alembic for migrations from the start, or add later?
- Redis connection pooling strategy for multiple services?
