# Proposal: Add SMTP Service

## Overview
Implement SMTP client service for sending emails including message composition, MIME encoding, draft management, and reliable delivery with retry logic.

## Motivation
The SMTP service handles outbound email with proper MIME formatting, authentication, and delivery confirmation, providing a reliable sending experience.

## Scope

### In Scope
- SMTP/ESMTP protocol client
- TLS/STARTTLS secure connections
- OAuth2 XOAUTH2 and plain authentication
- Message composition with MIME encoding
- Attachment handling
- Draft management
- Reply/Forward composition
- Send queue with retry logic

### Out of Scope
- IMAP operations (separate service)
- Template system
- Scheduling (send later)

## Technical Approach

### SMTP Client Architecture
```swift
actor SMTPClient {
    private var connection: NWConnection?

    func connect(to account: Account) async throws
    func disconnect() async

    func send(message: MIMEMessage) async throws -> SendResult
}
```

### Message Composer
Build properly formatted MIME messages:
```swift
class MessageComposer {
    func compose(
        from: EmailAddress,
        to: [EmailAddress],
        cc: [EmailAddress],
        bcc: [EmailAddress],
        subject: String,
        bodyPlain: String?,
        bodyHtml: String?,
        attachments: [AttachmentData]
    ) -> MIMEMessage

    func composeReply(
        to original: Message,
        from: EmailAddress,
        body: String,
        replyAll: Bool
    ) -> MIMEMessage

    func composeForward(
        original: Message,
        from: EmailAddress,
        to: [EmailAddress],
        body: String
    ) -> MIMEMessage
}
```

### Send Queue
Reliable delivery with offline support:
```swift
actor SendQueue {
    func enqueue(message: MIMEMessage, account: Account) async
    func processQueue() async
    func retryFailed() async
}
```

### Draft Service
Local draft management synced with IMAP Drafts folder:
```swift
actor DraftService {
    func saveDraft(_ compose: ComposeState) async throws -> Draft
    func loadDraft(_ id: UUID) async throws -> ComposeState
    func deleteDraft(_ id: UUID) async throws
    func syncDrafts(for account: Account) async throws
}
```

## Scenarios

### Scenario: Compose and Send New Message
- Given the user composes a new email
- When they click Send
- Then the message is MIME-encoded
- And queued for sending
- And sent via SMTP
- And copied to Sent folder via IMAP

### Scenario: Send with Attachments
- Given a message with file attachments
- When the message is sent
- Then attachments are base64 encoded
- And included as MIME parts
- And the complete message is transmitted

### Scenario: Reply to Message
- Given an existing message
- When the user replies
- Then In-Reply-To header is set
- And References chain is maintained
- And quoted content is included
- And subject has "Re:" prefix

### Scenario: Reply All
- Given a message with multiple recipients
- When the user chooses Reply All
- Then all original recipients (except self) are included
- And proper To/CC distribution is maintained

### Scenario: Forward Message
- Given an existing message
- When the user forwards it
- Then original content is quoted
- And attachments can be included
- And subject has "Fwd:" prefix

### Scenario: Save Draft
- Given a message being composed
- When the user saves as draft
- Then the draft is saved locally in SwiftData
- And optionally synced to IMAP Drafts folder

### Scenario: Offline Send
- Given no network connection
- When the user sends a message
- Then the message is queued locally
- And sent automatically when online
- And user is notified of queue status

### Scenario: Send Retry on Failure
- Given a temporary send failure
- When the error is transient
- Then the message is retried with backoff
- And permanent failures are reported to user

## Task Breakdown

1. Create `SMTPClient` actor with connection management
2. Implement NWConnection wrapper for SMTP
3. Implement SMTP command/response handling
4. Add STARTTLS upgrade support
5. Implement XOAUTH2 authentication for SMTP
6. Implement LOGIN/PLAIN authentication
7. Create `MIMEBuilder` for message construction
8. Implement multipart MIME encoding
9. Implement base64 attachment encoding
10. Create `MessageComposer` for compose/reply/forward
11. Implement reply recipient calculation
12. Implement forward content formatting
13. Create `SendQueue` actor for reliable delivery
14. Implement retry logic with exponential backoff
15. Create `DraftService` for local draft management
16. Implement draft sync with IMAP Drafts folder
17. Add sent message copy to Sent folder
