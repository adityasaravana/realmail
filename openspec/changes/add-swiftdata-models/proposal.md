# Proposal: Add SwiftData Models

## Overview
Define the core data models using SwiftData for persistent storage of email accounts, folders, messages, and attachments.

## Motivation
SwiftData provides a modern, Swift-native persistence layer that integrates seamlessly with SwiftUI and the Observation framework, enabling automatic UI updates when data changes.

## Scope

### In Scope
- Account model with connection settings
- Folder model with hierarchy support
- Message model with full email metadata
- Attachment model for file handling
- EmailAddress value type
- Model relationships and cascading deletes
- Query descriptors for common operations

### Out of Scope
- Network synchronization logic
- MIME parsing (handled by services)
- UI components

## Technical Approach

### Data Models

#### Account
```swift
@Model
class Account {
    @Attribute(.unique) var id: UUID
    var email: String
    var displayName: String?
    var provider: AccountProvider
    var imapHost: String
    var imapPort: Int
    var smtpHost: String
    var smtpPort: Int
    var authType: AuthType
    var isEnabled: Bool
    var lastSyncAt: Date?

    @Relationship(deleteRule: .cascade)
    var folders: [Folder]
}
```

#### Folder
```swift
@Model
class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var fullPath: String
    var folderType: FolderType
    var uidValidity: UInt32?
    var uidNext: UInt32?
    var messageCount: Int
    var unreadCount: Int

    var account: Account?
    var parent: Folder?

    @Relationship(deleteRule: .cascade)
    var children: [Folder]

    @Relationship(deleteRule: .cascade)
    var messages: [Message]
}
```

#### Message
```swift
@Model
class Message {
    @Attribute(.unique) var id: UUID
    var messageId: String?
    var subject: String?
    var fromAddress: String
    var fromName: String?
    var toAddresses: [String]
    var ccAddresses: [String]
    var bccAddresses: [String]
    var date: Date
    var bodyPlain: String?
    var bodyHtml: String?
    var snippet: String?
    var isRead: Bool
    var isFlagged: Bool
    var isDraft: Bool
    var imapUid: UInt32?
    var inReplyTo: String?
    var references: [String]
    var threadId: String?

    var folder: Folder?

    @Relationship(deleteRule: .cascade)
    var attachments: [Attachment]
}
```

#### Attachment
```swift
@Model
class Attachment {
    @Attribute(.unique) var id: UUID
    var filename: String
    var contentType: String
    var sizeBytes: Int64
    var contentId: String?
    var isInline: Bool
    @Attribute(.externalStorage) var content: Data?

    var message: Message?
}
```

### Supporting Types
- `AccountProvider`: Enum (gmail, outlook, icloud, custom)
- `AuthType`: Enum (oauth2, password)
- `FolderType`: Enum (inbox, sent, drafts, trash, spam, archive, custom)
- `EmailAddress`: Struct for parsed addresses

## Scenarios

### Scenario: Create New Account
- Given the user adds a new email account
- When account details are saved
- Then a new Account record is persisted with SwiftData
- And default folders are ready to be synced

### Scenario: Fetch Messages for Folder
- Given a folder with synced messages
- When the folder is selected
- Then messages are fetched using `@Query` with folder predicate
- And sorted by date descending

### Scenario: Mark Message as Read
- Given an unread message
- When the user views the message
- Then `message.isRead` is set to `true`
- And the folder's `unreadCount` is decremented

### Scenario: Delete Account with Cascade
- Given an account with folders and messages
- When the account is deleted
- Then all related folders, messages, and attachments are deleted

### Scenario: Thread Messages by References
- Given messages with In-Reply-To and References headers
- When messages are queried by threadId
- Then all messages in the conversation thread are returned

## Task Breakdown

1. Create `AccountProvider` enum with supported email providers
2. Create `AuthType` enum for authentication methods
3. Create `FolderType` enum for folder classification
4. Create `EmailAddress` struct for address parsing
5. Implement `Account` SwiftData model with relationships
6. Implement `Folder` SwiftData model with parent/children hierarchy
7. Implement `Message` SwiftData model with full metadata
8. Implement `Attachment` SwiftData model with external storage
9. Create ModelContainer configuration with schema
10. Add query descriptors for common fetch patterns
11. Create convenience initializers for models
12. Add computed properties for display formatting
