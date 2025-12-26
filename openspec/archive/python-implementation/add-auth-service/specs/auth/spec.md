# Auth Service Specification

## ADDED Requirements

### Requirement: OAuth2 Authorization Flow
The system SHALL support OAuth2 authorization for Gmail and Outlook accounts with automatic token management.

#### Scenario: Initiate Google OAuth flow
- **WHEN** `GET /auth/google` is called
- **THEN** user is redirected to Google consent screen
- **AND** redirect URL includes required scopes for Gmail access
- **AND** state parameter prevents CSRF attacks

#### Scenario: Handle Google OAuth callback
- **WHEN** Google redirects to callback URL with authorization code
- **THEN** code is exchanged for access and refresh tokens
- **AND** tokens are encrypted and stored
- **AND** account is created with Gmail configuration

#### Scenario: Initiate Microsoft OAuth flow
- **WHEN** `GET /auth/microsoft` is called
- **THEN** user is redirected to Microsoft consent screen
- **AND** redirect URL includes required scopes for Outlook access

#### Scenario: Handle Microsoft OAuth callback
- **WHEN** Microsoft redirects to callback URL with authorization code
- **THEN** code is exchanged for access and refresh tokens
- **AND** tokens are encrypted and stored
- **AND** account is created with Outlook configuration

#### Scenario: Refresh expired token
- **WHEN** an OAuth2 access token expires
- **THEN** refresh token is used to obtain new access token
- **AND** new tokens are stored
- **AND** operation proceeds with new token

#### Scenario: Handle refresh token failure
- **WHEN** token refresh fails (revoked, expired)
- **THEN** account status is set to requires_reauth
- **AND** user is notified to re-authorize

### Requirement: Credential Storage
The system SHALL store account credentials securely with encryption at rest.

#### Scenario: Store OAuth tokens
- **WHEN** OAuth2 tokens are received
- **THEN** tokens are encrypted using Fernet symmetric encryption
- **AND** encryption key is derived from application secret

#### Scenario: Store password credentials
- **WHEN** IMAP/SMTP password credentials are provided
- **THEN** password is encrypted before storage
- **AND** plain text password is never stored or logged

#### Scenario: Retrieve credentials
- **WHEN** credentials are needed for IMAP/SMTP connection
- **THEN** encrypted values are decrypted in memory
- **AND** decrypted values are not persisted

#### Scenario: Rotate encryption key
- **WHEN** encryption key rotation is triggered
- **THEN** all credentials are re-encrypted with new key
- **AND** old key is securely discarded

### Requirement: Account Management
The system SHALL support creating, viewing, updating, and deleting email accounts.

#### Scenario: Add account with OAuth
- **WHEN** OAuth flow completes successfully
- **THEN** account is created with provider configuration
- **AND** IMAP/SMTP servers are auto-configured
- **AND** initial sync is triggered

#### Scenario: Add account with credentials
- **WHEN** `POST /accounts` is called with server configuration
- **THEN** credentials are validated against server
- **AND** account is created if validation succeeds
- **AND** validation errors are returned if it fails

#### Scenario: List accounts
- **WHEN** `GET /accounts` is called
- **THEN** all accounts are returned without sensitive data
- **AND** account status and sync timestamps are included

#### Scenario: Get account details
- **WHEN** `GET /accounts/{id}` is called
- **THEN** account details are returned
- **AND** folder structure and message counts are included
- **AND** credentials are not exposed

#### Scenario: Delete account
- **WHEN** `DELETE /accounts/{id}` is called
- **THEN** account and all associated data are removed
- **AND** OAuth tokens are revoked if applicable
- **AND** cached data is cleared

### Requirement: Connection Verification
The system SHALL verify account credentials can connect to email servers.

#### Scenario: Verify new account
- **WHEN** `POST /accounts/{id}/verify` is called
- **THEN** IMAP connection is attempted
- **AND** SMTP connection is attempted
- **AND** success or failure status is returned for each

#### Scenario: Verify OAuth account
- **WHEN** verifying an OAuth-based account
- **THEN** token validity is checked
- **AND** XOAUTH2 authentication is tested
- **AND** token refresh is attempted if needed

#### Scenario: Report verification failure
- **WHEN** verification fails
- **THEN** specific error is returned (auth failed, server unreachable, TLS error)
- **AND** troubleshooting hints are provided

### Requirement: Provider Configuration
The system SHALL maintain configuration for common email providers with auto-discovery support.

#### Scenario: Gmail configuration
- **WHEN** a Gmail account is added
- **THEN** IMAP server is set to imap.gmail.com:993 (SSL)
- **AND** SMTP server is set to smtp.gmail.com:587 (STARTTLS)
- **AND** OAuth2 scopes include mail.google.com

#### Scenario: Outlook configuration
- **WHEN** an Outlook account is added
- **THEN** IMAP server is set to outlook.office365.com:993 (SSL)
- **AND** SMTP server is set to smtp.office365.com:587 (STARTTLS)
- **AND** OAuth2 scopes include IMAP.AccessAsUser.All and SMTP.Send

#### Scenario: Custom provider
- **WHEN** a custom email provider is configured
- **THEN** user provides IMAP/SMTP server addresses and ports
- **AND** security settings (SSL/STARTTLS/None) are configurable
- **AND** authentication method is selectable

#### Scenario: Auto-discover settings
- **WHEN** email domain supports autodiscovery
- **THEN** server settings are automatically retrieved
- **AND** user can override discovered settings

### Requirement: Account Status Tracking
The system SHALL track account status and health for monitoring.

#### Scenario: Track active account
- **WHEN** account connections succeed
- **THEN** status is set to active
- **AND** last_successful_sync is updated

#### Scenario: Track authentication error
- **WHEN** authentication fails repeatedly
- **THEN** status is set to auth_error
- **AND** error message is stored
- **AND** sync is paused until resolved

#### Scenario: Track connectivity error
- **WHEN** server is unreachable
- **THEN** status is set to connection_error
- **AND** retry is scheduled
- **AND** status reverts to active when connection succeeds

### Requirement: Auth REST API
The system SHALL expose REST endpoints for authentication and account management.

#### Scenario: OAuth initiation endpoints
- **WHEN** OAuth flow endpoints are called
- **THEN** proper redirects are issued
- **AND** PKCE is used for enhanced security

#### Scenario: Account CRUD endpoints
- **WHEN** account management endpoints are called
- **THEN** proper HTTP status codes are returned
- **AND** validation errors include field-level details

#### Scenario: Rate limiting
- **WHEN** too many requests are made to auth endpoints
- **THEN** rate limiting is applied
- **AND** 429 status with Retry-After header is returned
