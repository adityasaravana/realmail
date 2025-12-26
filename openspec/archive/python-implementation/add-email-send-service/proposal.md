# Change: Add Email Send Service

## Why
Users need to compose and send emails. The send service handles SMTP connections, draft management, and outbound message delivery with proper MIME construction.

## What Changes
- Implement async SMTP client with authentication support
- Create message composition with MIME structure
- Add draft saving and editing functionality
- Implement attachment handling with size limits
- Add sent message tracking and delivery status
- Expose REST API for composing, drafting, and sending emails

## Impact
- Affected specs: `email-send` (new capability)
- Affected code: Creates `realmail/services/send/` package
- Dependencies: Requires `add-core-infrastructure` to be implemented first
