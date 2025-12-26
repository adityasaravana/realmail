# Proposal: Add App Infrastructure

## Overview
Set up the foundational Swift macOS application structure including the Xcode project, app entry point, shared utilities, and configuration management.

## Motivation
A native macOS email client requires proper project structure, dependency injection patterns, and shared utilities before implementing domain-specific features.

## Scope

### In Scope
- Xcode project with proper structure
- SwiftUI app entry point with environment configuration
- Keychain manager for secure credential storage
- App configuration and constants
- Shared extensions and utilities
- Error handling patterns

### Out of Scope
- Email protocol implementations (IMAP/SMTP)
- SwiftData models (separate proposal)
- UI views beyond basic shell

## Technical Approach

### Project Structure
```
RealMail/
├── RealMail.xcodeproj
├── RealMail/
│   ├── App/
│   │   ├── RealMailApp.swift      # App entry point
│   │   └── AppEnvironment.swift   # Environment configuration
│   ├── Utilities/
│   │   ├── KeychainManager.swift  # Secure credential storage
│   │   ├── Logger.swift           # Logging utility
│   │   └── Extensions/            # Swift extensions
│   └── Resources/
│       └── Assets.xcassets        # App assets
```

### KeychainManager
Actor-based keychain wrapper for thread-safe credential operations:
- Store/retrieve passwords and OAuth tokens
- Automatic item updates
- Secure deletion

### AppEnvironment
Dependency container using SwiftUI Environment:
- ModelContainer injection
- Service registrations
- Configuration values

## Scenarios

### Scenario: App Launch with Empty State
- Given the app is launched for the first time
- When the main window appears
- Then the user sees an empty state prompting to add an account

### Scenario: Keychain Store and Retrieve
- Given a password needs to be stored
- When `KeychainManager.shared.save(password:forAccount:)` is called
- Then the password is securely stored in macOS Keychain
- And can be retrieved with `KeychainManager.shared.password(forAccount:)`

### Scenario: Keychain Delete Credentials
- Given credentials exist for an account
- When `KeychainManager.shared.deleteCredentials(forAccount:)` is called
- Then all credentials for that account are removed from Keychain

## Task Breakdown

1. Create Xcode project structure with proper folder organization
2. Implement `RealMailApp.swift` entry point with WindowGroup
3. Create `AppEnvironment.swift` for dependency injection
4. Implement `KeychainManager` actor for secure credential storage
5. Create `Logger` utility with unified logging
6. Add common Swift extensions (Date, String, Data)
7. Configure app entitlements for Keychain access and network
8. Set up Assets.xcassets with app icon placeholder
9. Add Package.swift for any SPM dependencies
10. Create AppConstants for configuration values
