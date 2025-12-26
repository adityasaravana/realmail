# SMTP Service

## ADDED Requirements

### Requirement: SMTP Connection
The SMTP client SHALL establish secure TLS connections to SMTP servers with STARTTLS support.

#### Scenario: Connect with TLS
- Given valid SMTP server configuration
- When connect is called
- Then TLS connection is established
- And the client is ready for authentication

#### Scenario: STARTTLS Upgrade
- Given a server requiring STARTTLS
- When connection is established on port 587
- Then connection is upgraded to TLS
- And secure communication is enabled

### Requirement: SMTP Authentication
The SMTP client SHALL support XOAUTH2 and LOGIN authentication methods.

#### Scenario: OAuth Authentication
- Given OAuth credentials
- When authenticating with XOAUTH2
- Then authentication succeeds
- And MAIL FROM can be sent

#### Scenario: Password Authentication
- Given username and password
- When authenticating with LOGIN
- Then authentication succeeds
- And MAIL FROM can be sent

### Requirement: Message Composition
The message composer SHALL build properly formatted MIME messages.

#### Scenario: Simple Message
- Given text content
- When compose is called
- Then a valid MIME message is created
- And headers are properly formatted

#### Scenario: HTML Message
- Given plain and HTML content
- When compose is called
- Then multipart/alternative is created
- And both parts are included

### Requirement: Attachment Handling
The message composer SHALL properly encode and attach files.

#### Scenario: Add Attachment
- Given a file to attach
- When compose is called with attachment
- Then file is base64 encoded
- And Content-Disposition is set
- And multipart/mixed structure is used

### Requirement: Reply Composition
The message composer SHALL create proper reply messages with threading.

#### Scenario: Reply to Message
- Given an original message
- When composeReply is called
- Then In-Reply-To header is set
- And References chain is maintained
- And subject has "Re:" prefix

#### Scenario: Reply All
- Given a message with multiple recipients
- When composeReply is called with replyAll true
- Then all original recipients are included
- And sender is excluded from recipients

### Requirement: Forward Composition
The message composer SHALL create forward messages with original content.

#### Scenario: Forward Message
- Given an original message
- When composeForward is called
- Then original content is quoted
- And subject has "Fwd:" prefix

#### Scenario: Forward with Attachments
- Given a message with attachments
- When forwarded with includeAttachments true
- Then original attachments are included

### Requirement: Send Queue
The send queue SHALL provide reliable delivery with retry logic.

#### Scenario: Queue Message
- Given a composed message
- When enqueue is called
- Then message is added to queue
- And will be processed in order

#### Scenario: Offline Send
- Given no network connection
- When the user sends a message
- Then the message is queued locally
- And sent automatically when online

#### Scenario: Retry on Failure
- Given a transient send failure
- When the send fails
- Then message is retried with backoff
- And permanent failures are reported

### Requirement: Draft Service
The draft service SHALL manage local drafts with optional IMAP sync.

#### Scenario: Save Draft
- Given a message being composed
- When saveDraft is called
- Then draft is saved locally
- And can be resumed later

#### Scenario: Load Draft
- Given a saved draft
- When loadDraft is called
- Then compose state is restored
- And editing can continue

#### Scenario: Delete Draft
- Given a draft
- When deleteDraft is called
- Then draft is removed
- And any IMAP copy is deleted

### Requirement: Sent Copy
After sending, the message SHALL be copied to the Sent folder via IMAP.

#### Scenario: Copy to Sent
- Given a successfully sent message
- When send completes
- Then message is appended to Sent folder
- And appears in sent messages

### Requirement: Send Result
The SMTP client SHALL report detailed send results including server response.

#### Scenario: Successful Send
- Given a valid message
- When send succeeds
- Then success result is returned
- And message ID is available

#### Scenario: Send Failure
- Given an invalid recipient
- When send fails
- Then error details are returned
- And user can correct and retry
