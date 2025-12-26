# Email Send Service Specification

## ADDED Requirements

### Requirement: SMTP Connection Management
The system SHALL maintain SMTP connections for sending emails with proper authentication and encryption.

#### Scenario: Establish SMTP connection
- **WHEN** sending is initiated for an account
- **THEN** an async SMTP connection is established
- **AND** STARTTLS or direct SSL is used based on configuration

#### Scenario: SMTP authentication
- **WHEN** the SMTP server requires authentication
- **THEN** credentials are provided using the appropriate method (PLAIN, LOGIN, or OAuth2)
- **AND** authentication failures are reported with clear error messages

#### Scenario: Handle send failure
- **WHEN** SMTP sending fails
- **THEN** the error is captured with SMTP response code
- **AND** the message is queued for retry if appropriate
- **AND** permanent failures are reported to the user

### Requirement: Message Composition
The system SHALL compose email messages with proper MIME structure supporting plain text, HTML, and attachments.

#### Scenario: Compose plain text message
- **WHEN** a message with only plain text body is composed
- **THEN** a simple text/plain MIME message is created
- **AND** UTF-8 encoding is used

#### Scenario: Compose HTML message
- **WHEN** a message with HTML body is composed
- **THEN** a multipart/alternative message is created
- **AND** both text/plain and text/html parts are included

#### Scenario: Compose message with attachments
- **WHEN** a message has attachments
- **THEN** a multipart/mixed message is created
- **AND** attachments are encoded as base64
- **AND** appropriate Content-Type and Content-Disposition headers are set

#### Scenario: Encode non-ASCII headers
- **WHEN** headers contain non-ASCII characters
- **THEN** RFC 2047 encoded-words are used
- **AND** UTF-8 encoding is preferred

### Requirement: Reply and Forward
The system SHALL support replying to and forwarding existing messages with proper threading headers.

#### Scenario: Reply to message
- **WHEN** a reply is composed
- **THEN** In-Reply-To header references the original Message-ID
- **AND** References header includes the conversation chain
- **AND** subject is prefixed with "Re:" if not already present
- **AND** original message is quoted in the body

#### Scenario: Reply all
- **WHEN** a reply-all is composed
- **THEN** all original recipients (To, CC) are included
- **AND** the sender is excluded from recipients

#### Scenario: Forward message
- **WHEN** a message is forwarded
- **THEN** subject is prefixed with "Fwd:"
- **AND** original message is included as attachment or inline based on preference
- **AND** original attachments can be optionally included

### Requirement: Draft Management
The system SHALL support saving, editing, and sending draft messages.

#### Scenario: Create draft
- **WHEN** a draft is created via API
- **THEN** the draft is stored in the database
- **AND** a draft ID is returned for future reference

#### Scenario: Auto-save draft
- **WHEN** a message is being composed (client indicates auto-save)
- **THEN** the draft is automatically saved at intervals
- **AND** previous auto-save is replaced

#### Scenario: Update draft
- **WHEN** a draft is updated
- **THEN** all fields (recipients, subject, body, attachments) can be modified
- **AND** updated timestamp is recorded

#### Scenario: Send draft
- **WHEN** a draft is sent
- **THEN** the draft is converted to a sent message
- **AND** the draft is deleted from drafts storage
- **AND** the message appears in Sent folder

#### Scenario: Sync draft to IMAP
- **WHEN** a draft is saved
- **THEN** the draft is uploaded to the IMAP Drafts folder
- **AND** IMAP UID is stored for reference

### Requirement: Attachment Handling
The system SHALL support adding, removing, and managing attachments with size limits.

#### Scenario: Add attachment
- **WHEN** a file is uploaded as attachment
- **THEN** file is stored with draft or message
- **AND** MIME type is detected from content
- **AND** filename and size are recorded

#### Scenario: Validate attachment size
- **WHEN** attachment exceeds configured maximum size
- **THEN** upload is rejected with clear error message
- **AND** maximum allowed size is indicated

#### Scenario: Total message size limit
- **WHEN** combined message size exceeds limit
- **THEN** send is blocked with error message
- **AND** current size and limit are indicated

#### Scenario: Inline attachment
- **WHEN** an image is embedded in HTML body
- **THEN** Content-ID is generated and assigned
- **AND** HTML references the CID for inline display

### Requirement: Send Queue
The system SHALL queue outbound messages for reliable delivery with retry support.

#### Scenario: Queue message for sending
- **WHEN** a send request is made
- **THEN** message is queued in Redis
- **AND** immediate acknowledgment is returned to client
- **AND** queue worker processes the send

#### Scenario: Retry failed send
- **WHEN** sending fails with a temporary error
- **THEN** message is requeued with exponential backoff
- **AND** retry count is tracked
- **AND** maximum retry attempts are enforced

#### Scenario: Report permanent failure
- **WHEN** sending fails permanently (invalid recipient, rejected, etc.)
- **THEN** message status is set to failed
- **AND** failure reason is recorded
- **AND** user is notified

### Requirement: Sent Message Tracking
The system SHALL track sent messages and copy them to the Sent folder.

#### Scenario: Copy to Sent folder
- **WHEN** a message is successfully sent
- **THEN** a copy is uploaded to the IMAP Sent folder
- **AND** the local database is updated with sent status

#### Scenario: Track delivery status
- **WHEN** a message is sent
- **THEN** status transitions through: queued → sending → sent (or failed)
- **AND** timestamps are recorded for each transition

### Requirement: Send REST API
The system SHALL expose REST endpoints for composing, drafting, and sending messages.

#### Scenario: Send new message
- **WHEN** `POST /messages` is called with message data
- **THEN** message is validated and queued for sending
- **AND** message ID and status are returned

#### Scenario: Create draft
- **WHEN** `POST /drafts` is called
- **THEN** draft is created and stored
- **AND** draft ID is returned

#### Scenario: Update draft
- **WHEN** `PUT /drafts/{id}` is called
- **THEN** draft is updated with new content
- **AND** updated draft is returned

#### Scenario: Send draft
- **WHEN** `POST /drafts/{id}/send` is called
- **THEN** draft is sent using the send queue
- **AND** message ID and status are returned

#### Scenario: Reply to message
- **WHEN** `POST /messages/{id}/reply` is called
- **THEN** reply is composed with proper threading
- **AND** reply is queued for sending

#### Scenario: Forward message
- **WHEN** `POST /messages/{id}/forward` is called
- **THEN** forward is composed with original content
- **AND** forward is queued for sending
