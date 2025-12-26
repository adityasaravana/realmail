# Change: Add Email Sync Service

## Why
Users need to receive and view emails from their accounts. The sync service connects to IMAP servers, downloads messages, and keeps the local database synchronized with the remote mailbox.

## What Changes
- Implement IMAP connection management with async support
- Create folder synchronization logic
- Implement message downloading with MIME parsing
- Add incremental sync using IMAP UIDs and UIDVALIDITY
- Implement IDLE push notifications for real-time updates
- Expose REST API for triggering sync and viewing messages

## Impact
- Affected specs: `email-sync` (new capability)
- Affected code: Creates `realmail/services/sync/` package
- Dependencies: Requires `add-core-infrastructure` to be implemented first
