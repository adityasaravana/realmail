# Change: Add Core Infrastructure

## Why
RealMail needs foundational infrastructure before implementing domain services. This includes shared Pydantic models, database setup, configuration management, and common utilities that all microservices will depend on.

## What Changes
- Add shared Pydantic models for email entities (Message, Folder, Account, Attachment)
- Set up SQLite database with async support via aiosqlite
- Implement Redis connection management for caching
- Create BaseSettings configuration with environment variable support
- Establish project structure for microservices architecture
- Add common utilities (logging, error handling, MIME parsing)

## Impact
- Affected specs: `core` (new capability)
- Affected code: Creates foundational `realmail/` package structure
- Dependencies: None (first proposal)
