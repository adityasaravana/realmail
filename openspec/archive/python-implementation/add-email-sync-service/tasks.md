# Tasks: Add Email Sync Service

## 1. IMAP Client
- [ ] 1.1 Create `realmail/services/sync/imap_client.py` with async IMAP connection
- [ ] 1.2 Implement connection pooling per account
- [ ] 1.3 Handle STARTTLS and SSL/TLS connections
- [ ] 1.4 Implement reconnection logic with exponential backoff

## 2. Folder Sync
- [ ] 2.1 Create `realmail/services/sync/folder_sync.py`
- [ ] 2.2 Fetch folder list from IMAP server
- [ ] 2.3 Map special folders (INBOX, Sent, Drafts, Trash, Spam)
- [ ] 2.4 Sync folder hierarchy to database

## 3. Message Sync
- [ ] 3.1 Create `realmail/services/sync/message_sync.py`
- [ ] 3.2 Implement initial full sync for new accounts
- [ ] 3.3 Implement incremental sync using UIDVALIDITY and UIDs
- [ ] 3.4 Download message headers and bodies
- [ ] 3.5 Parse MIME content using core utilities
- [ ] 3.6 Extract and store attachments

## 4. Real-time Updates
- [ ] 4.1 Implement IMAP IDLE for push notifications
- [ ] 4.2 Handle new message notifications
- [ ] 4.3 Handle flag changes (read, starred, deleted)
- [ ] 4.4 Publish events to Redis pub/sub

## 5. REST API
- [ ] 5.1 Create FastAPI router for sync service
- [ ] 5.2 `POST /accounts/{id}/sync` - Trigger manual sync
- [ ] 5.3 `GET /accounts/{id}/folders` - List folders
- [ ] 5.4 `GET /folders/{id}/messages` - List messages with pagination
- [ ] 5.5 `GET /messages/{id}` - Get full message with body and attachments
- [ ] 5.6 `PATCH /messages/{id}` - Update flags (read, starred)

## 6. Background Jobs
- [ ] 6.1 Implement periodic sync scheduler
- [ ] 6.2 Add sync status tracking per account
- [ ] 6.3 Handle sync conflicts and errors

## 7. Testing
- [ ] 7.1 Create mock IMAP server for testing
- [ ] 7.2 Write unit tests for sync logic
- [ ] 7.3 Write integration tests for API endpoints
