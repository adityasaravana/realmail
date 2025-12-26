# Auth Service

## ADDED Requirements

### Requirement: OAuth2 Gmail Authentication
The auth service SHALL support OAuth2 authentication for Gmail using ASWebAuthenticationSession.

#### Scenario: Gmail OAuth Flow
- Given the user wants to add a Gmail account
- When they initiate OAuth login
- Then ASWebAuthenticationSession opens Google's login page
- And after successful login, tokens are received
- And tokens are securely stored in Keychain

#### Scenario: Gmail OAuth Error
- Given the OAuth flow is started
- When the user cancels or an error occurs
- Then appropriate error is returned
- And user can retry

### Requirement: OAuth2 Outlook Authentication
The auth service SHALL support OAuth2 authentication for Outlook/Microsoft 365 accounts.

#### Scenario: Outlook OAuth Flow
- Given the user wants to add an Outlook account
- When they initiate OAuth login
- Then ASWebAuthenticationSession opens Microsoft's login page
- And after successful login, tokens are received
- And tokens are securely stored in Keychain

### Requirement: Token Refresh
The auth service SHALL automatically refresh OAuth2 tokens before expiration.

#### Scenario: Automatic Refresh
- Given an access token is about to expire
- When a sync operation is requested
- Then the refresh token is used to obtain new access token
- And the new tokens are stored in Keychain
- And the operation proceeds with fresh credentials

#### Scenario: Refresh Failure
- Given the refresh token is invalid
- When refresh is attempted
- Then user is prompted to re-authenticate
- And appropriate error is shown

### Requirement: Password Authentication
The auth service SHALL support basic password authentication for custom IMAP/SMTP servers.

#### Scenario: Store Password
- Given the user configures a custom IMAP server
- When they provide username and password
- Then the password is stored in macOS Keychain
- And can be retrieved for IMAP/SMTP connections

### Requirement: Credential Validation
The auth service SHALL be able to validate stored credentials by testing the connection.

#### Scenario: Valid Credentials
- Given stored credentials
- When validateCredentials is called
- Then a test connection is made
- And success is returned

#### Scenario: Invalid Credentials
- Given incorrect credentials
- When validateCredentials is called
- Then connection fails
- And authentication error is returned

### Requirement: Provider Configuration
The auth service SHALL provide server configuration for known email providers.

#### Scenario: Gmail Config
- Given a Gmail email address
- When provider config is requested
- Then correct IMAP/SMTP hosts are returned
- And OAuth settings are included

#### Scenario: Auto-Detection
- Given an unknown email domain
- When provider is detected
- Then custom server config is used
- And user provides server details

### Requirement: Token Revocation
The auth service SHALL revoke OAuth tokens when an account is removed.

#### Scenario: Revoke on Delete
- Given an authenticated OAuth account
- When the user removes the account
- Then OAuth tokens are revoked with the provider
- And all credentials are deleted from Keychain

### Requirement: OAuthCredentials Model
The auth service SHALL use a structured model for OAuth token storage.

#### Scenario: Token Storage
- Given OAuth tokens are received
- When stored in Keychain
- Then access_token, refresh_token, and expiration are preserved
- And can be decoded on retrieval
