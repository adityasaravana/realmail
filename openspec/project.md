# Project Context

## Purpose
RealMail is a native macOS email client application that allows users to send, receive, and manage their emails. Built as a modern, performant desktop application using Swift and SwiftUI for an excellent native user experience.

## Tech Stack
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI with AppKit integration where needed
- **Architecture:** MVVM (Model-View-ViewModel) with Combine for reactive data flow
- **Persistence:** SwiftData (Core Data successor) for local storage
- **Keychain:** macOS Keychain for secure credential storage
- **Networking:** async/await with URLSession for HTTP, custom implementations for IMAP/SMTP
- **Testing:** XCTest with Swift Testing framework

## Project Conventions

### Code Style
- Follow Swift API Design Guidelines
- Use `camelCase` for functions, properties, and variables
- Use `PascalCase` for types (structs, classes, enums, protocols)
- Use `SCREAMING_SNAKE_CASE` for global constants
- Maximum line length: 120 characters
- Use documentation comments (`///`) for public APIs

### SwiftUI Conventions
- Use `@Observable` macro (Swift 5.9+) for view models
- Prefer `@State` for view-local state
- Use `@Environment` for dependency injection
- Extract reusable views into separate files
- Keep views focused and composable
- Use `ViewModifier` for reusable styling

### Architecture Patterns
- **MVVM Architecture:** Clear separation of concerns
  - **Model:** Data structures and business logic
  - **View:** SwiftUI views (declarative UI)
  - **ViewModel:** `@Observable` classes bridging Model and View
- **Repository Pattern:** Abstract data source access
- **Service Layer:** Protocol-based services for email operations
- **Combine Integration:** Reactive streams for async updates
- **Actor Isolation:** Use actors for thread-safe state management

### SwiftData Conventions
- Use `@Model` macro for persistent entities
- Define explicit relationships with `@Relationship`
- Use `ModelContainer` as environment dependency
- Prefer batch operations for large data sets
- Handle migrations with versioned schemas

### Testing Strategy
- Use XCTest for unit and integration tests
- Use Swift Testing (`@Test`) for new test code
- Mock protocols for dependency injection in tests
- UI tests with XCUITest for critical user flows
- Test async code with `async` test functions

### Project Structure
```
RealMail/
├── App/                    # App entry point and configuration
│   ├── RealMailApp.swift
│   └── AppDelegate.swift
├── Models/                 # SwiftData models and domain types
│   ├── Account.swift
│   ├── Folder.swift
│   ├── Message.swift
│   └── Attachment.swift
├── ViewModels/             # Observable view models
│   ├── AccountsViewModel.swift
│   ├── MailboxViewModel.swift
│   └── ComposeViewModel.swift
├── Views/                  # SwiftUI views
│   ├── Sidebar/
│   ├── MailList/
│   ├── MessageDetail/
│   └── Compose/
├── Services/               # Email protocol services
│   ├── Auth/
│   ├── IMAP/
│   └── SMTP/
├── Utilities/              # Shared utilities
│   ├── KeychainManager.swift
│   ├── MIMEParser.swift
│   └── Extensions/
└── Resources/              # Assets, localizations
```

## Domain Context

### Email Protocols
- **IMAP (Internet Message Access Protocol):** Used for receiving and synchronizing emails. Supports folders, flags, and server-side search. Connection stays open for IDLE push notifications.
- **SMTP (Simple Mail Transfer Protocol):** Used for sending outbound emails. Requires authentication (usually STARTTLS or SSL/TLS).
- **OAuth2:** Modern authentication flow for Gmail, Outlook, and other providers (avoids storing passwords).

### Email Message Structure
- **Envelope:** Routing information (From, To, CC, BCC, Reply-To)
- **Headers:** Metadata including Message-ID, In-Reply-To, References (for threading), Date, Subject
- **Body:** Can be multipart MIME with:
  - `text/plain` - Plain text version
  - `text/html` - HTML formatted version
  - `multipart/alternative` - Contains both plain and HTML
  - `multipart/mixed` - Message with attachments
- **Attachments:** Binary files encoded as base64 within MIME parts

### Email Encoding
- **MIME (Multipurpose Internet Mail Extensions):** Standard for non-ASCII text and attachments
- **Content-Transfer-Encoding:** base64 for binary, quoted-printable for mostly-ASCII text
- **Character Sets:** UTF-8 preferred, but must handle legacy encodings (ISO-8859-1, Windows-1252)
- **Header Encoding:** RFC 2047 encoded-words for non-ASCII in headers (e.g., `=?UTF-8?B?...?=`)

### Mailbox Organization
- **Standard Folders:** INBOX, Sent, Drafts, Trash, Spam/Junk, Archive
- **Custom Folders/Labels:** User-created organizational structure
- **Flags:** \Seen, \Answered, \Flagged, \Deleted, \Draft, plus custom flags

### Conversation Threading
- **Message-ID:** Unique identifier for each email
- **In-Reply-To:** References the Message-ID of the parent email
- **References:** Chain of Message-IDs in the conversation thread
- **Subject-based fallback:** Group by normalized subject when headers are missing

### Email Addresses
- **Format:** `local-part@domain` (RFC 5321)
- **Display Name:** Optional `"Display Name" <email@domain.com>` format
- **Validation:** Must validate syntax and optionally verify domain (MX records)
- **Internationalized Email:** Support for non-ASCII domains (IDN) and local parts (EAI)

## Important Constraints
- Must be a native macOS application (no Electron/web wrapper)
- Minimum macOS version: 14.0 (Sonoma) for SwiftData and Observation framework
- Credentials must be stored in macOS Keychain (never in plain text)
- Must handle email encoding properly (MIME, base64, quoted-printable)
- App must work offline with local cache, sync when online
- Follow Apple Human Interface Guidelines for macOS

## External Dependencies
- **IMAP Servers:** Gmail, Outlook, custom mail servers for receiving mail
- **SMTP Servers:** For sending outbound email
- **OAuth2 Providers:** Google, Microsoft for modern authentication
- **macOS Keychain:** Secure credential storage
