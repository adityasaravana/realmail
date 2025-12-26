import Foundation
import SwiftData

/// Mailbox folder model with hierarchy support and IMAP metadata.
@Model
final class Folder {
    /// Unique identifier for the folder.
    @Attribute(.unique)
    var id: UUID

    /// Folder name as displayed to the user.
    var name: String

    /// Full IMAP path (e.g., "INBOX/Newsletters").
    var path: String

    /// Semantic folder type (inbox, sent, drafts, etc.).
    var folderType: FolderType

    /// Number of unread messages in this folder.
    var unreadCount: Int

    /// Total number of messages in this folder.
    var totalCount: Int

    /// IMAP UIDVALIDITY for cache invalidation.
    var uidValidity: UInt32?

    /// Highest known UID for incremental sync.
    var highestModSeq: UInt64?

    /// Whether this folder supports IMAP IDLE.
    var supportsIdle: Bool

    /// Sort order for display (lower = higher in list).
    var sortOrder: Int

    /// Account this folder belongs to.
    var account: Account?

    /// Parent folder for nested hierarchy.
    var parent: Folder?

    /// Child folders in hierarchy.
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var children: [Folder]

    /// Messages in this folder.
    @Relationship(deleteRule: .cascade, inverse: \Message.folder)
    var messages: [Message]

    /// Creates a new folder.
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        folderType: FolderType = .other,
        unreadCount: Int = 0,
        totalCount: Int = 0,
        uidValidity: UInt32? = nil,
        highestModSeq: UInt64? = nil,
        supportsIdle: Bool = false,
        sortOrder: Int = 100,
        account: Account? = nil,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.folderType = folderType
        self.unreadCount = unreadCount
        self.totalCount = totalCount
        self.uidValidity = uidValidity
        self.highestModSeq = highestModSeq
        self.supportsIdle = supportsIdle
        self.sortOrder = sortOrder
        self.account = account
        self.parent = parent
        self.children = []
        self.messages = []
    }
}

// MARK: - Folder Type

/// Semantic folder types with IMAP attribute detection.
enum FolderType: String, Codable, CaseIterable {
    case inbox
    case drafts
    case sent
    case trash
    case archive
    case spam
    case flagged
    case all
    case other

    /// SF Symbol icon for this folder type.
    var iconName: String {
        switch self {
        case .inbox: return "tray.fill"
        case .drafts: return "doc.fill"
        case .sent: return "paperplane.fill"
        case .trash: return "trash.fill"
        case .archive: return "archivebox.fill"
        case .spam: return "xmark.bin.fill"
        case .flagged: return "flag.fill"
        case .all: return "tray.full.fill"
        case .other: return "folder.fill"
        }
    }

    /// Display name for this folder type.
    var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .drafts: return "Drafts"
        case .sent: return "Sent"
        case .trash: return "Trash"
        case .archive: return "Archive"
        case .spam: return "Spam"
        case .flagged: return "Flagged"
        case .all: return "All Mail"
        case .other: return "Folder"
        }
    }

    /// Default sort order for standard folder types.
    var defaultSortOrder: Int {
        switch self {
        case .inbox: return 0
        case .flagged: return 1
        case .drafts: return 2
        case .sent: return 3
        case .archive: return 4
        case .spam: return 5
        case .trash: return 6
        case .all: return 7
        case .other: return 100
        }
    }

    /// Detects folder type from IMAP attributes.
    static func detect(from attributes: [String], name: String) -> FolderType {
        let lowercasedAttrs = attributes.map { $0.lowercased() }
        let lowercasedName = name.lowercased()

        // Check IMAP special-use attributes (RFC 6154)
        if lowercasedAttrs.contains("\\inbox") || lowercasedName == "inbox" {
            return .inbox
        }
        if lowercasedAttrs.contains("\\drafts") || lowercasedName == "drafts" {
            return .drafts
        }
        if lowercasedAttrs.contains("\\sent") || lowercasedName == "sent" || lowercasedName.contains("sent") {
            return .sent
        }
        if lowercasedAttrs.contains("\\trash") || lowercasedName == "trash" || lowercasedName.contains("deleted") {
            return .trash
        }
        if lowercasedAttrs.contains("\\archive") || lowercasedName == "archive" {
            return .archive
        }
        if lowercasedAttrs.contains("\\junk") || lowercasedName == "spam" || lowercasedName == "junk" {
            return .spam
        }
        if lowercasedAttrs.contains("\\flagged") || lowercasedName == "flagged" || lowercasedName == "starred" {
            return .flagged
        }
        if lowercasedAttrs.contains("\\all") || lowercasedName.contains("all mail") {
            return .all
        }

        return .other
    }
}
