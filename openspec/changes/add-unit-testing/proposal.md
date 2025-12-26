# Change: Add Comprehensive Unit Testing Framework

## Why
The codebase currently lacks unit tests. Comprehensive testing is essential for:
- Ensuring code correctness and reliability
- Enabling confident refactoring
- Documenting expected behavior
- Catching regressions early
- Supporting CI/CD pipelines

## What Changes
- Add unit tests for all SwiftData models (Account, Folder, Message, Attachment, EmailAddress)
- Add unit tests for all service layers (AuthService, IMAPClient, SMTPClient, SendQueueService)
- Add unit tests for ViewModels (MailboxViewModel, ComposeViewModel)
- Add unit tests for utility functions (MIMEParser, EmailAddress parsing, Date formatting)
- Add UI tests for critical user flows
- Configure test targets in Package.swift/Xcode project
- Add mocking protocols for dependency injection

## Impact
- Affected specs: Creates new `testing` capability
- Affected code:
  - `Tests/RealMailTests/` - All test files
  - `Package.swift` - Test target configuration
  - `RealMail/Services/` - Protocol extraction for mocking
