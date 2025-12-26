# IMAP Service

## ADDED Requirements

### Requirement: IMAP Connection
The IMAP client SHALL establish secure TLS connections to IMAP servers with STARTTLS support.

#### Scenario: Connect with TLS
- Given valid account credentials
- When connect is called
- Then TLS connection is established
- And the client is ready for authentication

#### Scenario: STARTTLS Upgrade
- Given a server requiring STARTTLS
- When connection is established
- Then plain connection is upgraded to TLS
- And secure communication is enabled

### Requirement: IMAP Authentication
The IMAP client SHALL support XOAUTH2 for OAuth providers and LOGIN for password auth.

#### Scenario: OAuth Authentication
- Given OAuth credentials
- When authenticating with XOAUTH2
- Then authentication succeeds
- And commands can be executed

#### Scenario: Password Authentication
- Given username and password
- When authenticating with LOGIN
- Then authentication succeeds
- And commands can be executed

### Requirement: Folder Listing
The IMAP client SHALL list all mailbox folders with attributes and hierarchy.

#### Scenario: List Folders
- Given an authenticated connection
- When listFolders is called
- Then all mailbox folders are returned
- And folder types are inferred from attributes
- And hierarchy is preserved

### Requirement: Folder Selection
The IMAP client SHALL select folders and return folder status with counts.

#### Scenario: Select Folder
- Given an authenticated connection
- When selectFolder is called
- Then folder becomes active for operations
- And message count, unread count, and UIDs are returned

### Requirement: Message Headers Fetch
The IMAP client SHALL fetch message headers efficiently in batches.

#### Scenario: Fetch Headers
- Given a selected folder with messages
- When fetchMessages is called with a UID range
- Then message headers are returned
- And includes from, to, subject, date

### Requirement: Message Body Fetch
The IMAP client SHALL fetch full message bodies with MIME structure.

#### Scenario: Fetch Body
- Given a message UID
- When fetchBody is called
- Then full MIME message is returned
- And text/plain and text/html parts are extracted
- And attachments are identified

### Requirement: MIME Parsing
The IMAP service SHALL parse multipart MIME structures into usable parts.

#### Scenario: Parse Multipart
- Given a multipart MIME message
- When parsed
- Then plain text part is extracted
- And HTML part is extracted
- And attachments are listed with metadata

#### Scenario: Handle Encoding
- Given a message with quoted-printable or base64 encoding
- When parsed
- Then content is properly decoded
- And character set is handled

### Requirement: Flag Management
The IMAP client SHALL support setting and clearing message flags.

#### Scenario: Mark as Read
- Given an unread message UID
- When setFlags is called with Seen flag
- Then the flag is set on server
- And local model can be updated

#### Scenario: Toggle Flagged
- Given a message UID
- When Flagged flag is toggled
- Then the flag state changes on server

### Requirement: IDLE Push Notifications
The IMAP client SHALL support IDLE command for real-time new message notifications.

#### Scenario: IDLE New Message
- Given an IDLE-capable server
- When the client enters IDLE mode
- Then new message events are received in real-time
- And the handler is called for each event

#### Scenario: IDLE Timeout
- Given an active IDLE session
- When server timeout approaches
- Then IDLE is renewed automatically
- And no messages are missed

### Requirement: Sync Service
The IMAP sync service SHALL orchestrate folder and message synchronization.

#### Scenario: Initial Sync
- Given a newly added account
- When initial sync runs
- Then all folders are synced
- And message headers are fetched
- And unread counts are accurate

#### Scenario: Incremental Sync
- Given a previously synced account
- When incremental sync runs
- Then only new messages are fetched
- And deleted messages are detected
- And flag changes are synchronized

### Requirement: Connection Management
The IMAP client SHALL handle reconnection and keepalive.

#### Scenario: Reconnect on Disconnect
- Given an active connection
- When connection is lost
- Then automatic reconnection is attempted
- And pending operations are retried

### Requirement: Attachment Download
The IMAP client SHALL support fetching individual attachment content.

#### Scenario: Download Attachment
- Given a message with attachments
- When an attachment is requested
- Then the attachment body part is fetched
- And content is decoded from base64
