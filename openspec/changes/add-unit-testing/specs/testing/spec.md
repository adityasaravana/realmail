# Testing Specification

## ADDED Requirements

### Requirement: Unit Test Coverage
The system SHALL provide unit tests for all core components with a minimum coverage target of 80%.

#### Scenario: Model layer testing
- **WHEN** running model tests
- **THEN** all SwiftData model properties and relationships SHALL be validated
- **AND** model initialization with various inputs SHALL be tested
- **AND** computed properties SHALL return expected values

#### Scenario: Service layer testing
- **WHEN** running service tests
- **THEN** all public service methods SHALL have corresponding test cases
- **AND** error handling paths SHALL be tested
- **AND** async operations SHALL be properly awaited in tests

#### Scenario: ViewModel testing
- **WHEN** running ViewModel tests
- **THEN** all state changes SHALL be verified
- **AND** user actions SHALL produce expected side effects
- **AND** error states SHALL be properly handled

### Requirement: Test Infrastructure
The system SHALL provide testing utilities and mocking support for isolated unit testing.

#### Scenario: Mock services available
- **WHEN** writing tests for components with dependencies
- **THEN** mock implementations SHALL be available for all service protocols
- **AND** mocks SHALL allow configurable responses and error injection

#### Scenario: Test helpers available
- **WHEN** writing tests requiring test data
- **THEN** factory methods SHALL exist for creating test fixtures
- **AND** in-memory SwiftData containers SHALL be available for model tests

### Requirement: SwiftData Model Tests
All SwiftData models (Account, Folder, Message, Attachment) SHALL have comprehensive unit tests.

#### Scenario: Account model validation
- **WHEN** creating an Account with valid data
- **THEN** all properties SHALL be correctly initialized
- **AND** the AccountProvider enum SHALL be correctly assigned

#### Scenario: Account credential storage
- **WHEN** storing OAuth credentials for an Account
- **THEN** credentials SHALL be accessible via the account's email
- **AND** token refresh status SHALL be verifiable

#### Scenario: Folder hierarchy validation
- **WHEN** creating nested Folder structures
- **THEN** parent-child relationships SHALL be correctly maintained
- **AND** FolderType SHALL be determinable from folder attributes

#### Scenario: Folder message count
- **WHEN** querying a Folder's unread count
- **THEN** the count SHALL accurately reflect unread messages
- **AND** count updates SHALL propagate correctly

#### Scenario: Message flag operations
- **WHEN** marking a Message as read/unread
- **THEN** the isRead property SHALL update correctly
- **AND** folder unread counts SHALL update accordingly

#### Scenario: Message threading
- **WHEN** messages have threading headers (In-Reply-To, References)
- **THEN** thread relationships SHALL be correctly identified
- **AND** reply chains SHALL be traversable

#### Scenario: Attachment metadata
- **WHEN** creating an Attachment
- **THEN** filename, mimeType, and size SHALL be correctly stored
- **AND** content disposition SHALL be properly handled

### Requirement: Email Address Tests
The EmailAddress struct SHALL be thoroughly tested for parsing and formatting.

#### Scenario: Parse standard email format
- **WHEN** parsing "user@example.com"
- **THEN** address property SHALL be "user@example.com"
- **AND** name property SHALL be nil

#### Scenario: Parse display name format
- **WHEN** parsing "John Doe <john@example.com>"
- **THEN** address property SHALL be "john@example.com"
- **AND** name property SHALL be "John Doe"

#### Scenario: Parse quoted display name
- **WHEN** parsing "\"Doe, John\" <john@example.com>"
- **THEN** address property SHALL be "john@example.com"
- **AND** name property SHALL be "Doe, John"

#### Scenario: Invalid email rejection
- **WHEN** parsing an invalid email string
- **THEN** initialization SHALL return nil

#### Scenario: XOAUTH2 string generation
- **WHEN** generating XOAUTH2 authentication string
- **THEN** the format SHALL be "user=email\x01auth=Bearer token\x01\x01"

### Requirement: Auth Service Tests
The AuthService actor SHALL have comprehensive tests for OAuth2 flows.

#### Scenario: OAuth PKCE challenge generation
- **WHEN** initiating OAuth authentication
- **THEN** a valid code verifier SHALL be generated
- **AND** code challenge SHALL be the base64url SHA256 of the verifier

#### Scenario: Token refresh on expiry
- **WHEN** credentials are expired and refresh token is available
- **THEN** tokens SHALL be automatically refreshed
- **AND** new credentials SHALL be stored

#### Scenario: Keychain credential storage
- **WHEN** OAuth credentials are obtained
- **THEN** they SHALL be securely stored in Keychain
- **AND** retrieval SHALL return the same credentials

### Requirement: IMAP Client Tests
The IMAPClient SHALL have tests for protocol operations.

#### Scenario: Command formatting
- **WHEN** generating IMAP commands
- **THEN** commands SHALL follow RFC 3501 format
- **AND** tags SHALL be correctly incremented

#### Scenario: Response parsing
- **WHEN** parsing IMAP server responses
- **THEN** tagged responses SHALL be correctly identified
- **AND** untagged data SHALL be properly extracted

#### Scenario: Mailbox listing
- **WHEN** requesting mailbox list
- **THEN** folder hierarchy SHALL be correctly parsed
- **AND** special-use attributes SHALL be detected

#### Scenario: Message header parsing
- **WHEN** fetching message headers
- **THEN** From, To, Subject, Date SHALL be extracted
- **AND** encoded headers SHALL be decoded (RFC 2047)

### Requirement: SMTP Client Tests
The SMTPClient SHALL have tests for email sending operations.

#### Scenario: Connection establishment
- **WHEN** connecting to SMTP server
- **THEN** EHLO response SHALL be parsed
- **AND** supported capabilities SHALL be detected

#### Scenario: Authentication
- **WHEN** authenticating with XOAUTH2
- **THEN** the authentication string SHALL be properly encoded
- **AND** successful authentication SHALL be detected

#### Scenario: Message transmission
- **WHEN** sending an email message
- **THEN** MAIL FROM, RCPT TO, DATA commands SHALL be sent
- **AND** successful delivery SHALL be confirmed

### Requirement: Message Composer Tests
The MessageComposer SHALL have tests for MIME message generation.

#### Scenario: Plain text message
- **WHEN** composing a plain text message
- **THEN** Content-Type SHALL be text/plain
- **AND** headers SHALL include From, To, Subject, Date, Message-ID

#### Scenario: HTML message with plain fallback
- **WHEN** composing a message with HTML and plain text
- **THEN** Content-Type SHALL be multipart/alternative
- **AND** both parts SHALL be included

#### Scenario: Message with attachments
- **WHEN** composing a message with attachments
- **THEN** Content-Type SHALL be multipart/mixed
- **AND** attachments SHALL be base64 encoded

#### Scenario: Reply headers
- **WHEN** composing a reply
- **THEN** In-Reply-To header SHALL reference original Message-ID
- **AND** References header SHALL include thread chain

### Requirement: ViewModel Tests
ViewModels SHALL be testable with mock dependencies.

#### Scenario: MailboxViewModel sync
- **WHEN** triggering sync operation
- **THEN** isSyncing state SHALL be true during sync
- **AND** syncProgress SHALL update incrementally
- **AND** isSyncing SHALL be false after completion

#### Scenario: MailboxViewModel message selection
- **WHEN** selecting a message
- **THEN** selectedMessage SHALL update
- **AND** message body fetch SHALL be triggered if needed

#### Scenario: ComposeViewModel send
- **WHEN** sending a composed message
- **THEN** message SHALL be queued for sending
- **AND** isSending state SHALL reflect operation status

#### Scenario: ComposeViewModel validation
- **WHEN** attempting to send without recipients
- **THEN** sendError SHALL indicate missing recipients
- **AND** send operation SHALL not proceed

### Requirement: Send Queue Tests
The SendQueueService SHALL have tests for offline queuing behavior.

#### Scenario: Message queuing
- **WHEN** queuing a message for sending
- **THEN** message SHALL be persisted with pending status
- **AND** a unique ID SHALL be returned

#### Scenario: Retry on failure
- **WHEN** a send attempt fails with transient error
- **THEN** message SHALL remain in queue
- **AND** retry SHALL be scheduled with backoff

#### Scenario: Network state handling
- **WHEN** device goes offline
- **THEN** pending messages SHALL wait for connectivity
- **AND** sending SHALL resume when online

### Requirement: Integration Tests
Integration tests SHALL verify end-to-end flows with SwiftData persistence.

#### Scenario: Account persistence
- **WHEN** creating and saving an Account
- **THEN** account SHALL be retrievable after app restart simulation
- **AND** related folders and messages SHALL be preserved

#### Scenario: Message sync persistence
- **WHEN** syncing messages from server
- **THEN** messages SHALL be persisted to SwiftData
- **AND** subsequent launches SHALL show cached messages

### Requirement: Test Execution
Tests SHALL be executable via command line and CI/CD pipelines.

#### Scenario: Command line execution
- **WHEN** running `./run.sh test`
- **THEN** all unit tests SHALL execute
- **AND** results SHALL be reported with pass/fail status

#### Scenario: CI/CD integration
- **WHEN** code is pushed to repository
- **THEN** tests SHALL run automatically via GitHub Actions
- **AND** build status SHALL reflect test results
