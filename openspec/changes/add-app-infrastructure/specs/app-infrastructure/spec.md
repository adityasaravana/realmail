# App Infrastructure

## ADDED Requirements

### Requirement: Xcode Project Structure
The application SHALL have a properly organized Xcode project with modular folder structure for App, Models, ViewModels, Views, Services, and Utilities.

#### Scenario: Project Organization
- **WHEN** the Xcode project is opened
- **THEN** folders are organized by feature domain
- **AND** shared utilities are in a common location

### Requirement: SwiftUI App Entry Point
The app SHALL have a SwiftUI-based entry point using @main attribute with proper WindowGroup and Scene configuration.

#### Scenario: App Launch
- **WHEN** the app is launched for the first time
- **THEN** the main window appears
- **AND** the user sees an empty state prompting to add an account

### Requirement: Keychain Manager
The app SHALL provide secure credential storage using macOS Keychain through an actor-based manager for thread safety.

#### Scenario: Store Password
- **WHEN** a password needs to be stored
- **AND** KeychainManager.shared.save is called
- **THEN** the password is securely stored in macOS Keychain

#### Scenario: Retrieve Password
- **WHEN** KeychainManager.shared.password is called
- **THEN** the stored password is retrieved
- **AND** matches the original value

#### Scenario: Delete Credentials
- **WHEN** KeychainManager.shared.deleteCredentials is called
- **THEN** all credentials for that account are removed from Keychain

### Requirement: App Environment Configuration
The app SHALL provide dependency injection through SwiftUI Environment with ModelContainer and service registrations.

#### Scenario: Environment Injection
- **WHEN** the app is launched
- **AND** views access environment values
- **THEN** ModelContainer is available
- **AND** required services are registered

### Requirement: Logging Utility
The app SHALL provide unified logging using OSLog with appropriate subsystem and categories.

#### Scenario: Log Messages
- **WHEN** events occur in the app
- **THEN** log messages include appropriate level
- **AND** can be viewed in Console.app

### Requirement: App Entitlements
The app SHALL have proper entitlements for Keychain access and network client capabilities.

#### Scenario: Keychain Access
- **WHEN** the app needs to access Keychain
- **THEN** access is granted via entitlements
- **AND** no security errors occur

### Requirement: Common Extensions
The app SHALL provide Swift extensions for common operations on Date, String, and Data types.

#### Scenario: Date Formatting
- **WHEN** a Date value is formatted for email display
- **THEN** appropriate format is used
- **AND** timezone is handled correctly
