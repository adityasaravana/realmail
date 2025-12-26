# Core Infrastructure Specification

## ADDED Requirements

### Requirement: Configuration Management
The system SHALL provide centralized configuration using Pydantic BaseSettings with environment variable support prefixed with `REALMAIL_`.

#### Scenario: Load configuration from environment
- **WHEN** the application starts
- **THEN** configuration values are loaded from environment variables
- **AND** missing required values raise validation errors
- **AND** default values are applied for optional settings

#### Scenario: Override configuration for testing
- **WHEN** tests run with custom configuration
- **THEN** configuration can be overridden programmatically
- **AND** environment variables are not required

### Requirement: Database Connection Management
The system SHALL provide async SQLite database connections using aiosqlite with connection pooling support.

#### Scenario: Acquire database connection
- **WHEN** a service requests a database connection
- **THEN** a connection is provided from the pool
- **AND** the connection supports async context manager usage

#### Scenario: Handle connection errors
- **WHEN** the database is unavailable
- **THEN** a `DatabaseConnectionError` is raised
- **AND** the error includes diagnostic information

### Requirement: Redis Cache Management
The system SHALL provide Redis connection management for caching with automatic serialization/deserialization of Pydantic models.

#### Scenario: Cache Pydantic model
- **WHEN** a Pydantic model is cached with a key and TTL
- **THEN** the model is serialized to JSON and stored in Redis
- **AND** the TTL is applied correctly

#### Scenario: Retrieve cached model
- **WHEN** a cached model is retrieved by key
- **THEN** the JSON is deserialized back to the Pydantic model type
- **AND** cache misses return None

### Requirement: Account Model
The system SHALL provide Pydantic models for email accounts with variants for creation, update, and response.

#### Scenario: Create account model validation
- **WHEN** an AccountCreate model is instantiated
- **THEN** email address is validated for correct format
- **AND** provider is validated against supported providers (gmail, outlook, imap)

#### Scenario: Account response serialization
- **WHEN** an AccountResponse is serialized
- **THEN** sensitive fields (oauth_token, password) are excluded
- **AND** computed fields (folder_count, unread_count) are included

### Requirement: Folder Model
The system SHALL provide Pydantic models for email folders/mailboxes with support for standard and custom folders.

#### Scenario: Standard folder identification
- **WHEN** a folder model is created with a standard folder type
- **THEN** the folder is marked as a system folder (inbox, sent, drafts, trash, spam, archive)
- **AND** system folders cannot be deleted or renamed

#### Scenario: Nested folder support
- **WHEN** a folder has a parent_id
- **THEN** the folder is treated as a subfolder
- **AND** the full path is computed from the hierarchy

### Requirement: Message Model
The system SHALL provide Pydantic models for email messages with proper handling of headers, body variants, and threading.

#### Scenario: Message creation with headers
- **WHEN** a MessageCreate model is instantiated
- **THEN** required headers (from, to, subject) are validated
- **AND** optional headers (cc, bcc, reply_to) are accepted

#### Scenario: Message body variants
- **WHEN** a message has both plain text and HTML body
- **THEN** both variants are stored
- **AND** the preferred display format can be specified

#### Scenario: Threading via References header
- **WHEN** a message has In-Reply-To or References headers
- **THEN** the message is linked to its conversation thread
- **AND** thread_id is computed from the root message

### Requirement: Attachment Model
The system SHALL provide Pydantic models for email attachments with metadata and content handling.

#### Scenario: Attachment metadata
- **WHEN** an attachment model is created
- **THEN** filename, content_type, and size are captured
- **AND** content_id is captured for inline attachments

#### Scenario: Attachment content storage
- **WHEN** attachment content is stored
- **THEN** content is base64 encoded for database storage
- **AND** original binary content can be retrieved

### Requirement: MIME Parsing Utilities
The system SHALL provide utilities for parsing and constructing MIME email messages.

#### Scenario: Parse multipart message
- **WHEN** a raw MIME message is parsed
- **THEN** headers are extracted and decoded (RFC 2047)
- **AND** body parts are identified (plain, html, attachments)
- **AND** attachments are extracted with metadata

#### Scenario: Construct MIME message
- **WHEN** a message is composed with body and attachments
- **THEN** a valid MIME structure is created
- **AND** appropriate Content-Transfer-Encoding is applied

### Requirement: Structured Logging
The system SHALL provide structured JSON logging with request context propagation.

#### Scenario: Log with context
- **WHEN** a log message is emitted within a request
- **THEN** request_id and user context are included
- **AND** output is JSON formatted for log aggregation

#### Scenario: Configure log level
- **WHEN** REALMAIL_LOG_LEVEL environment variable is set
- **THEN** only messages at or above that level are emitted

### Requirement: Custom Exceptions
The system SHALL provide a hierarchy of custom exceptions for consistent error handling across services.

#### Scenario: Domain exception handling
- **WHEN** a domain error occurs (e.g., MessageNotFound)
- **THEN** the exception includes error code and message
- **AND** the exception can be mapped to HTTP status codes

#### Scenario: External service errors
- **WHEN** an external service fails (IMAP, SMTP, Redis)
- **THEN** the exception wraps the original error
- **AND** includes service name and operation context
