# Proposal: Add IMAP Service

## Overview
Implement IMAP client service for email synchronization including folder listing, message fetching, flag management, and IDLE push notifications.

## Motivation
The IMAP service is the core of email retrieval, handling the complex protocol interactions needed to sync mailboxes efficiently while maintaining connection state.

## Scope

### In Scope
- IMAP4rev1 protocol client implementation
- TLS/STARTTLS secure connections
- OAuth2 XOAUTH2 and plain authentication
- Folder listing and sync
- Message fetch (headers, body, structure)
- Flag management (read, flagged, deleted)
- IDLE push notification support
- MIME parsing for message bodies

### Out of Scope
- SMTP sending (separate proposal)
- Full-text search (future enhancement)
- Offline message composition

## Technical Approach

### IMAP Client Architecture
```swift
actor IMAPClient {
    private var connection: NWConnection?
    private var state: IMAPState

    func connect(to account: Account) async throws
    func disconnect() async

    func listFolders() async throws -> [IMAPFolder]
    func selectFolder(_ path: String) async throws -> FolderStatus
    func fetchMessages(range: UIDRange) async throws -> [IMAPMessage]
    func fetchBody(uid: UInt32) async throws -> MIMEMessage
    func setFlags(uid: UInt32, flags: MessageFlags) async throws
    func idle(handler: @escaping (IMAPEvent) -> Void) async throws
}
```

### Network Layer
Use Network.framework (NWConnection) for:
- TCP connection with TLS
- STARTTLS upgrade
- Connection state monitoring
- Automatic reconnection

### MIME Parsing
Parse multipart MIME structures:
```swift
struct MIMEMessage {
    let headers: [String: String]
    let parts: [MIMEPart]

    var textPlain: String?
    var textHtml: String?
    var attachments: [MIMEAttachment]
}
```

### Sync Strategy
Efficient sync using IMAP UID:
1. Compare local UIDVALIDITY with server
2. Fetch new UIDs since last sync
3. Detect deleted messages
4. Batch fetch headers, then bodies on-demand

## Scenarios

### Scenario: Connect and Authenticate
- Given valid account credentials
- When `connect(to:)` is called
- Then TLS connection is established
- And XOAUTH2 or LOGIN authentication succeeds
- And the client is ready for commands

### Scenario: Sync Folder List
- Given an authenticated connection
- When `listFolders()` is called
- Then all mailbox folders are returned
- And folder types are inferred from attributes/names
- And hierarchy is preserved

### Scenario: Initial Message Sync
- Given a selected folder with messages
- When initial sync is performed
- Then message headers are fetched in batches
- And messages are stored in SwiftData
- And unread count is updated

### Scenario: Incremental Sync
- Given a previously synced folder
- When incremental sync runs
- Then only new messages (UID > last) are fetched
- And deleted messages are detected and removed
- And flag changes are synchronized

### Scenario: Fetch Message Body
- Given a message with only headers synced
- When the user opens the message
- Then full MIME body is fetched
- And body is parsed into plain/html parts
- And attachments are identified

### Scenario: IDLE Push Notification
- Given an IDLE-capable server
- When the client enters IDLE mode
- Then new message events are received in real-time
- And the handler is called for each event
- And UI can refresh immediately

### Scenario: Mark Message as Read
- Given an unread message
- When the user reads the message
- Then `\Seen` flag is set on server
- And local model is updated
- And unread count reflects the change

## Task Breakdown

1. Create `IMAPClient` actor with connection state
2. Implement NWConnection wrapper for TCP/TLS
3. Implement IMAP command/response parser
4. Add STARTTLS upgrade support
5. Implement XOAUTH2 authentication
6. Implement LOGIN/PLAIN authentication
7. Implement LIST command for folders
8. Implement SELECT/EXAMINE for folder selection
9. Implement FETCH for message headers
10. Implement FETCH for message bodies
11. Implement STORE for flag changes
12. Create MIMEParser for body parsing
13. Implement IDLE command with event handling
14. Add connection keepalive and reconnection
15. Create IMAPSyncService for orchestrating sync
16. Implement batch processing for large mailboxes
