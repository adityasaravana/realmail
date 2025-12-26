# Change: Add Auth Service

## Why
Users need to add email accounts securely. The auth service handles OAuth2 flows for Gmail/Outlook, stores credentials securely, and manages account lifecycle.

## What Changes
- Implement OAuth2 authorization flows for Gmail and Outlook
- Support traditional IMAP/SMTP credentials for generic providers
- Create secure credential storage with encryption
- Implement token refresh for OAuth2 accounts
- Add account CRUD operations
- Expose REST API for account management

## Impact
- Affected specs: `auth` (new capability)
- Affected code: Creates `realmail/services/auth/` package
- Dependencies: Requires `add-core-infrastructure` to be implemented first
