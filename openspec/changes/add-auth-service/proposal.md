# Proposal: Add Auth Service

## Overview
Implement authentication services for email providers including OAuth2 flows for Gmail and Outlook, and basic password authentication for generic IMAP/SMTP servers.

## Motivation
Modern email providers require OAuth2 authentication for security. The auth service must handle the OAuth flow, token refresh, and secure credential storage in macOS Keychain.

## Scope

### In Scope
- OAuth2 authentication flow for Gmail and Outlook
- ASWebAuthenticationSession for OAuth in macOS
- Token refresh mechanism
- Password-based authentication storage
- Credential validation
- Provider configuration

### Out of Scope
- IMAP/SMTP connection handling (separate service)
- Account UI (separate proposal)
- Enterprise SSO/SAML

## Technical Approach

### OAuth2 Flow
Use ASWebAuthenticationSession for secure, system-provided OAuth:

```swift
actor AuthService {
    func authenticateWithOAuth(
        provider: AccountProvider
    ) async throws -> OAuthCredentials

    func refreshToken(
        for account: Account
    ) async throws -> OAuthCredentials

    func revokeToken(
        for account: Account
    ) async throws
}
```

### Provider Configuration
```swift
struct ProviderConfig {
    let name: String
    let imapHost: String
    let imapPort: Int
    let smtpHost: String
    let smtpPort: Int
    let oauthClientId: String?
    let oauthScopes: [String]
    let authorizationURL: URL?
    let tokenURL: URL?
}
```

### Credential Storage
Credentials stored in Keychain with account identifier:
- OAuth tokens: access_token, refresh_token, expiration
- Passwords: encrypted password string

### Token Refresh
Background actor monitors token expiration and refreshes proactively:
- Check expiration before each IMAP/SMTP operation
- Refresh 5 minutes before expiry
- Handle refresh failures with user notification

## Scenarios

### Scenario: OAuth2 Gmail Authentication
- Given the user wants to add a Gmail account
- When they initiate OAuth login
- Then ASWebAuthenticationSession opens Google's login page
- And after successful login, tokens are received
- And tokens are securely stored in Keychain

### Scenario: OAuth2 Token Refresh
- Given an access token is about to expire
- When a sync operation is requested
- Then the refresh token is used to obtain new access token
- And the new tokens are stored in Keychain
- And the operation proceeds with fresh credentials

### Scenario: Password Authentication Storage
- Given the user configures a custom IMAP server
- When they provide username and password
- Then the password is stored in macOS Keychain
- And can be retrieved for IMAP/SMTP connections

### Scenario: Credential Validation
- Given stored credentials
- When `validateCredentials(for:)` is called
- Then a test connection is made to verify credentials
- And returns success or appropriate error

### Scenario: Revoke OAuth Access
- Given an authenticated OAuth account
- When the user removes the account
- Then OAuth tokens are revoked with the provider
- And all credentials are deleted from Keychain

## Task Breakdown

1. Create `ProviderConfig` for Gmail with OAuth settings
2. Create `ProviderConfig` for Outlook with OAuth settings
3. Create `ProviderConfig` factory for custom IMAP/SMTP
4. Implement `OAuthCredentials` model for token storage
5. Implement `AuthService` actor with OAuth flow
6. Integrate ASWebAuthenticationSession for OAuth
7. Implement token refresh mechanism
8. Implement password credential storage via KeychainManager
9. Create credential validation with test connection
10. Implement token revocation for account removal
11. Add provider auto-detection from email domain
12. Handle OAuth errors with user-friendly messages
