# Tasks: Add Auth Service

## 1. OAuth2 Implementation
- [ ] 1.1 Create `realmail/services/auth/oauth.py`
- [ ] 1.2 Implement Google OAuth2 flow (Gmail)
- [ ] 1.3 Implement Microsoft OAuth2 flow (Outlook)
- [ ] 1.4 Handle OAuth2 callback and token exchange
- [ ] 1.5 Implement token refresh logic

## 2. Credential Management
- [ ] 2.1 Create `realmail/services/auth/credentials.py`
- [ ] 2.2 Implement encryption for stored credentials (using Fernet)
- [ ] 2.3 Secure password storage for traditional IMAP/SMTP
- [ ] 2.4 Store OAuth2 tokens with refresh capability

## 3. Account Repository
- [ ] 3.1 Create `realmail/services/auth/repository.py`
- [ ] 3.2 Implement account CRUD operations
- [ ] 3.3 Store account configuration (server, port, security)
- [ ] 3.4 Track account status (active, error, disabled)

## 4. Provider Configuration
- [ ] 4.1 Create `realmail/services/auth/providers.py`
- [ ] 4.2 Define Gmail configuration (IMAP/SMTP servers, OAuth scopes)
- [ ] 4.3 Define Outlook configuration
- [ ] 4.4 Support custom IMAP/SMTP server configuration

## 5. REST API
- [ ] 5.1 Create FastAPI router for auth service
- [ ] 5.2 `GET /auth/google` - Initiate Google OAuth flow
- [ ] 5.3 `GET /auth/google/callback` - Handle Google callback
- [ ] 5.4 `GET /auth/microsoft` - Initiate Microsoft OAuth flow
- [ ] 5.5 `GET /auth/microsoft/callback` - Handle Microsoft callback
- [ ] 5.6 `POST /accounts` - Add account with credentials
- [ ] 5.7 `GET /accounts` - List accounts
- [ ] 5.8 `GET /accounts/{id}` - Get account details
- [ ] 5.9 `DELETE /accounts/{id}` - Remove account
- [ ] 5.10 `POST /accounts/{id}/verify` - Test account connection

## 6. Testing
- [ ] 6.1 Create mock OAuth2 server for testing
- [ ] 6.2 Write unit tests for credential encryption
- [ ] 6.3 Write integration tests for account flow
