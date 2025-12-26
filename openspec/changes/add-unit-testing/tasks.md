## 1. Test Infrastructure Setup
- [ ] 1.1 Create Tests/RealMailTests directory structure
- [ ] 1.2 Configure test target in Package.swift
- [ ] 1.3 Create test utilities and helpers
- [ ] 1.4 Add mock implementations directory

## 2. Model Tests
- [ ] 2.1 Write Account model tests
- [ ] 2.2 Write Folder model tests
- [ ] 2.3 Write Message model tests
- [ ] 2.4 Write Attachment model tests
- [ ] 2.5 Write EmailAddress struct tests

## 3. Service Tests
- [ ] 3.1 Extract protocols from services for mocking
- [ ] 3.2 Write AuthService tests (OAuth flow, token refresh)
- [ ] 3.3 Write IMAPClient tests (connection, authentication, commands)
- [ ] 3.4 Write SMTPClient tests (connection, sending)
- [ ] 3.5 Write SendQueueService tests (queuing, retry logic)
- [ ] 3.6 Write DraftService tests

## 4. ViewModel Tests
- [ ] 4.1 Write MailboxViewModel tests
- [ ] 4.2 Write ComposeViewModel tests

## 5. Utility Tests
- [ ] 5.1 Write MessageComposer tests (MIME generation)
- [ ] 5.2 Write Date extension tests
- [ ] 5.3 Write Logger extension tests
- [ ] 5.4 Write Keychain helper tests

## 6. Integration Tests
- [ ] 6.1 Write SwiftData persistence tests
- [ ] 6.2 Write end-to-end sync flow tests

## 7. CI/CD
- [ ] 7.1 Add GitHub Actions workflow for tests
- [ ] 7.2 Add test coverage reporting
