# Tasks: Add Email Send Service

## 1. SMTP Client
- [ ] 1.1 Create `realmail/services/send/smtp_client.py` with async SMTP
- [ ] 1.2 Implement STARTTLS and SSL/TLS support
- [ ] 1.3 Handle authentication (PLAIN, LOGIN, OAuth2)
- [ ] 1.4 Implement connection pooling and retry logic

## 2. Message Composition
- [ ] 2.1 Create `realmail/services/send/composer.py`
- [ ] 2.2 Build MIME structure for plain text messages
- [ ] 2.3 Build MIME structure for HTML messages with plain fallback
- [ ] 2.4 Handle multipart messages with attachments
- [ ] 2.5 Implement proper header encoding (RFC 2047)

## 3. Draft Management
- [ ] 3.1 Create `realmail/services/send/drafts.py`
- [ ] 3.2 Implement draft creation and storage
- [ ] 3.3 Implement draft auto-save functionality
- [ ] 3.4 Handle draft-to-send conversion
- [ ] 3.5 Sync drafts to IMAP Drafts folder

## 4. Attachment Handling
- [ ] 4.1 Create `realmail/services/send/attachments.py`
- [ ] 4.2 Implement file upload with size validation
- [ ] 4.3 Detect and set correct MIME types
- [ ] 4.4 Handle inline attachments (images in HTML)

## 5. Send Queue
- [ ] 5.1 Create background send queue with Redis
- [ ] 5.2 Implement retry logic for failed sends
- [ ] 5.3 Track delivery status (queued, sent, failed)
- [ ] 5.4 Copy sent messages to Sent folder via IMAP

## 6. REST API
- [ ] 6.1 Create FastAPI router for send service
- [ ] 6.2 `POST /messages` - Send a new message
- [ ] 6.3 `POST /drafts` - Create a draft
- [ ] 6.4 `PUT /drafts/{id}` - Update a draft
- [ ] 6.5 `POST /drafts/{id}/send` - Send a draft
- [ ] 6.6 `DELETE /drafts/{id}` - Delete a draft
- [ ] 6.7 `POST /messages/{id}/reply` - Reply to a message
- [ ] 6.8 `POST /messages/{id}/forward` - Forward a message

## 7. Testing
- [ ] 7.1 Create mock SMTP server for testing
- [ ] 7.2 Write unit tests for MIME composition
- [ ] 7.3 Write integration tests for send flow
