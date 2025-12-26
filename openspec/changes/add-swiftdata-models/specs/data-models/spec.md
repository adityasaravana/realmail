# SwiftData Models

## ADDED Requirements

### Requirement: Account Model
The Account model SHALL store email account configuration including connection settings, authentication type, and relationships to folders.

#### Scenario: Create Account
- Given valid account configuration
- When the account is saved to SwiftData
- Then the account is persisted
- And can be retrieved by ID

#### Scenario: Account Relationships
- Given an account with folders
- When folders are added to the account
- Then the relationship is maintained
- And folders are accessible via account.folders

### Requirement: Folder Model
The Folder model SHALL represent mailbox folders with hierarchy support, unread counts, and IMAP metadata.

#### Scenario: Folder Hierarchy
- Given a parent folder
- When child folders are added
- Then the hierarchy is maintained
- And children are accessible via parent.children

#### Scenario: Unread Count
- Given a folder with messages
- When messages are marked read/unread
- Then unreadCount reflects the current state

### Requirement: Message Model
The Message model SHALL store complete email metadata including headers, body content, flags, and threading information.

#### Scenario: Store Message
- Given a parsed email message
- When saved to SwiftData
- Then all metadata is preserved
- And body content is stored

#### Scenario: Message Threading
- Given messages with In-Reply-To headers
- When queried by threadId
- Then related messages are grouped
- And conversation order is maintained

#### Scenario: Mark as Read
- Given an unread message
- When isRead is set to true
- Then the change is persisted
- And folder unreadCount decrements

### Requirement: Attachment Model
The Attachment model SHALL store file metadata and content with external storage for large files.

#### Scenario: Store Attachment
- Given an email with attachments
- When attachments are saved
- Then metadata is stored in-line
- And content uses external storage

#### Scenario: Attachment Access
- Given a stored attachment
- When content is requested
- Then binary data is retrieved
- And can be written to file

### Requirement: Supporting Enums
The data layer SHALL provide enums for AccountProvider, AuthType, and FolderType for type-safe categorization.

#### Scenario: Provider Configuration
- Given a provider enum value
- When creating an account
- Then appropriate defaults are applied
- And server settings are inferred

### Requirement: EmailAddress Type
A value type SHALL be provided for parsing and formatting email addresses with display name support.

#### Scenario: Parse Address
- Given a string like "John Doe <john@example.com>"
- When parsed as EmailAddress
- Then name is "John Doe"
- And address is "john@example.com"

#### Scenario: Format Address
- Given an EmailAddress with name
- When formatted as string
- Then RFC 5322 format is produced

### Requirement: Cascade Delete
Account deletion SHALL cascade to delete all related folders, messages, and attachments.

#### Scenario: Delete Account
- Given an account with folders and messages
- When the account is deleted
- Then all related data is removed
- And no orphaned records remain

### Requirement: ModelContainer Configuration
The app SHALL configure ModelContainer with proper schema including all models and migration support.

#### Scenario: Container Setup
- Given the app launches
- When ModelContainer is initialized
- Then all models are registered
- And persistence is ready
