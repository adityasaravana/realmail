# Email Sync Service Specification

## ADDED Requirements

### Requirement: IMAP Connection Management
The system SHALL maintain persistent IMAP connections to configured email accounts with automatic reconnection on failure.

#### Scenario: Establish IMAP connection
- **WHEN** an account is configured with IMAP credentials
- **THEN** an async IMAP connection is established
- **AND** STARTTLS or direct SSL is used based on server configuration

#### Scenario: Handle connection failure
- **WHEN** an IMAP connection fails or times out
- **THEN** reconnection is attempted with exponential backoff
- **AND** connection status is updated in the database
- **AND** failure events are logged with diagnostic information

#### Scenario: Connection pooling
- **WHEN** multiple operations require IMAP access for the same account
- **THEN** connections are reused from the pool
- **AND** pool size is configurable per account

### Requirement: Folder Synchronization
The system SHALL synchronize the folder structure from IMAP servers to the local database, mapping standard folders correctly.

#### Scenario: Initial folder sync
- **WHEN** an account is added or folder sync is triggered
- **THEN** all folders are fetched from the IMAP server
- **AND** standard folders (INBOX, Sent, Drafts, Trash, Spam) are identified
- **AND** folder hierarchy is preserved

#### Scenario: Detect folder changes
- **WHEN** folder sync runs after initial sync
- **THEN** new folders are added to the database
- **AND** deleted folders are marked as removed
- **AND** renamed folders are updated

#### Scenario: Map special folders
- **WHEN** the IMAP server uses non-standard names for special folders
- **THEN** the system uses IMAP SPECIAL-USE attributes to identify them
- **AND** falls back to common name patterns (e.g., "Sent Items", "[Gmail]/Sent")

### Requirement: Message Synchronization
The system SHALL download and synchronize messages from IMAP folders to the local database with support for incremental sync.

#### Scenario: Initial message sync
- **WHEN** a folder is synced for the first time
- **THEN** all messages are downloaded
- **AND** UIDVALIDITY is stored for future sync

#### Scenario: Incremental message sync
- **WHEN** a folder with existing messages is synced
- **THEN** only messages with UIDs greater than the last synced UID are fetched
- **AND** UIDVALIDITY is checked to detect mailbox reconstruction

#### Scenario: UIDVALIDITY change
- **WHEN** UIDVALIDITY has changed since last sync
- **THEN** the local folder is cleared
- **AND** a full resync is performed

#### Scenario: Download message content
- **WHEN** a message is synced
- **THEN** headers are parsed and stored (From, To, Subject, Date, Message-ID)
- **AND** body parts are extracted (plain text and HTML)
- **AND** attachments are identified and metadata is stored

#### Scenario: Handle large attachments
- **WHEN** a message has attachments larger than the configured threshold
- **THEN** attachment content is downloaded on demand
- **AND** only metadata is stored during initial sync

### Requirement: Message Flag Synchronization
The system SHALL synchronize message flags bidirectionally between the local database and IMAP server.

#### Scenario: Sync flags from server
- **WHEN** message sync occurs
- **THEN** IMAP flags (Seen, Answered, Flagged, Deleted, Draft) are synced to database
- **AND** local flags are updated to match server state

#### Scenario: Update flag on server
- **WHEN** a local flag is changed via API
- **THEN** the corresponding IMAP flag is updated on the server
- **AND** sync timestamp is updated

#### Scenario: Handle flag sync conflicts
- **WHEN** a flag is changed locally and remotely since last sync
- **THEN** server state takes precedence
- **AND** conflict is logged for audit

### Requirement: Real-time Push Notifications
The system SHALL use IMAP IDLE to receive real-time notifications of new messages and flag changes.

#### Scenario: Receive new message notification
- **WHEN** a new message arrives on the IMAP server
- **THEN** the IDLE connection receives the EXISTS notification
- **AND** the new message is fetched and stored
- **AND** a new_message event is published to Redis

#### Scenario: IDLE connection maintenance
- **WHEN** the IDLE connection has been active for 28 minutes
- **THEN** the connection is renewed to prevent timeout
- **AND** no messages are missed during renewal

#### Scenario: Fallback to polling
- **WHEN** the IMAP server does not support IDLE
- **THEN** periodic polling is used instead
- **AND** polling interval is configurable (default 60 seconds)

### Requirement: Sync REST API
The system SHALL expose REST endpoints for managing synchronization and accessing synced data.

#### Scenario: Trigger manual sync
- **WHEN** `POST /accounts/{id}/sync` is called
- **THEN** a sync job is queued for the account
- **AND** response includes job status and estimated completion

#### Scenario: List folders
- **WHEN** `GET /accounts/{id}/folders` is called
- **THEN** all synced folders are returned with message counts
- **AND** unread counts are included for each folder

#### Scenario: List messages with pagination
- **WHEN** `GET /folders/{id}/messages?page=1&size=50` is called
- **THEN** messages are returned sorted by date descending
- **AND** pagination metadata is included
- **AND** only headers are included (not full body)

#### Scenario: Get full message
- **WHEN** `GET /messages/{id}` is called
- **THEN** full message is returned including body and attachment metadata
- **AND** message is marked as read if not already

#### Scenario: Update message flags
- **WHEN** `PATCH /messages/{id}` is called with flag updates
- **THEN** local flags are updated immediately
- **AND** IMAP flag update is queued
- **AND** updated message is returned

### Requirement: Sync Status Tracking
The system SHALL track synchronization status and history for each account.

#### Scenario: Track sync progress
- **WHEN** a sync operation is in progress
- **THEN** current folder and progress percentage are available
- **AND** status is queryable via API

#### Scenario: Record sync history
- **WHEN** a sync operation completes
- **THEN** duration, message count, and any errors are recorded
- **AND** last successful sync timestamp is updated

#### Scenario: Handle sync errors
- **WHEN** a sync operation fails
- **THEN** error is recorded with context
- **AND** account status is updated to reflect the error
- **AND** retry is scheduled based on error type
