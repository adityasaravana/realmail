import Foundation
import SwiftData

/// Email message model with full metadata, body content, and threading support.
@Model
final class Message {
    /// Unique identifier for the message.
    @Attribute(.unique)
    var id: UUID

    /// IMAP UID for this message in its folder.
    var uid: UInt32

    /// Message-ID header value for threading.
    var messageId: String?

    /// Thread identifier (typically the root Message-ID).
    var threadId: String?

    /// In-Reply-To header for threading.
    var inReplyTo: String?

    /// References header chain for threading.
    var references: [String]

    /// Email subject line.
    var subject: String

    /// Sender email address.
    var fromAddress: String

    /// Sender display name.
    var fromName: String?

    /// Primary recipients (To).
    var toAddresses: [String]

    /// Carbon copy recipients (CC).
    var ccAddresses: [String]

    /// Blind carbon copy recipients (BCC).
    var bccAddresses: [String]

    /// Reply-To address if different from sender.
    var replyTo: String?

    /// Message date from Date header.
    var date: Date

    /// When this message was received/synced locally.
    var receivedAt: Date

    /// Plain text body content.
    var bodyText: String?

    /// HTML body content.
    var bodyHtml: String?

    /// Short preview snippet for list view.
    var snippet: String?

    /// Whether the message has been read.
    var isRead: Bool

    /// Whether the message is flagged/starred.
    var isFlagged: Bool

    /// Whether this is a draft message.
    var isDraft: Bool

    /// Whether this message has been answered.
    var isAnswered: Bool

    /// Whether this message has attachments.
    var hasAttachments: Bool

    /// Raw IMAP flags string array.
    var flags: [String]

    /// Message size in bytes.
    var size: Int

    /// Content-Type of the message.
    var contentType: String?

    /// Folder containing this message.
    var folder: Folder?

    /// Attachments belonging to this message.
    @Relationship(deleteRule: .cascade, inverse: \Attachment.message)
    var attachments: [Attachment]

    /// Creates a new message.
    init(
        id: UUID = UUID(),
        uid: UInt32,
        messageId: String? = nil,
        threadId: String? = nil,
        inReplyTo: String? = nil,
        references: [String] = [],
        subject: String,
        fromAddress: String,
        fromName: String? = nil,
        toAddresses: [String] = [],
        ccAddresses: [String] = [],
        bccAddresses: [String] = [],
        replyTo: String? = nil,
        date: Date,
        receivedAt: Date = Date(),
        bodyText: String? = nil,
        bodyHtml: String? = nil,
        snippet: String? = nil,
        isRead: Bool = false,
        isFlagged: Bool = false,
        isDraft: Bool = false,
        isAnswered: Bool = false,
        hasAttachments: Bool = false,
        flags: [String] = [],
        size: Int = 0,
        contentType: String? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.uid = uid
        self.messageId = messageId
        self.threadId = threadId
        self.inReplyTo = inReplyTo
        self.references = references
        self.subject = subject
        self.fromAddress = fromAddress
        self.fromName = fromName
        self.toAddresses = toAddresses
        self.ccAddresses = ccAddresses
        self.bccAddresses = bccAddresses
        self.replyTo = replyTo
        self.date = date
        self.receivedAt = receivedAt
        self.bodyText = bodyText
        self.bodyHtml = bodyHtml
        self.snippet = snippet
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.isDraft = isDraft
        self.isAnswered = isAnswered
        self.hasAttachments = hasAttachments
        self.flags = flags
        self.size = size
        self.contentType = contentType
        self.folder = folder
        self.attachments = []
    }
}

// MARK: - Computed Properties

extension Message {
    /// Formatted sender string with name if available.
    var formattedSender: String {
        if let name = fromName, !name.isEmpty {
            return name
        }
        return fromAddress.components(separatedBy: "@").first ?? fromAddress
    }

    /// Subject with "Re:" prefix removed for threading display.
    var normalizedSubject: String {
        subject.normalizedSubject
    }

    /// Whether this message is part of a thread.
    var isThreaded: Bool {
        inReplyTo != nil || !references.isEmpty
    }

    /// Effective reply-to address for composing replies.
    var effectiveReplyTo: String {
        replyTo ?? fromAddress
    }

    /// All recipient addresses combined.
    var allRecipients: [String] {
        toAddresses + ccAddresses + bccAddresses
    }
}

// MARK: - Flag Updates

extension Message {
    /// Updates the isRead flag and syncs with flags array.
    func markAsRead(_ read: Bool) {
        isRead = read
        if read {
            if !flags.contains("\\Seen") {
                flags.append("\\Seen")
            }
        } else {
            flags.removeAll { $0 == "\\Seen" }
        }
    }

    /// Updates the isFlagged flag and syncs with flags array.
    func setFlagged(_ flagged: Bool) {
        isFlagged = flagged
        if flagged {
            if !flags.contains("\\Flagged") {
                flags.append("\\Flagged")
            }
        } else {
            flags.removeAll { $0 == "\\Flagged" }
        }
    }

    /// Updates the isAnswered flag and syncs with flags array.
    func markAsAnswered(_ answered: Bool) {
        isAnswered = answered
        if answered {
            if !flags.contains("\\Answered") {
                flags.append("\\Answered")
            }
        } else {
            flags.removeAll { $0 == "\\Answered" }
        }
    }

    /// Syncs boolean flags from IMAP flags array.
    func syncFlagsFromIMAP() {
        isRead = flags.contains("\\Seen")
        isFlagged = flags.contains("\\Flagged")
        isAnswered = flags.contains("\\Answered")
        isDraft = flags.contains("\\Draft")
    }
}
