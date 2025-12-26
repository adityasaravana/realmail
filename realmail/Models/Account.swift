import Foundation
import SwiftData
import SwiftUI

/// Email account model with connection settings and relationships.
@Model
final class Account {
    /// Unique identifier for the account.
    @Attribute(.unique)
    var id: UUID

    /// Email address for this account.
    var email: String

    /// Display name for the account (e.g., "Work" or "Personal").
    var displayName: String?

    /// Email provider type.
    var provider: AccountProvider

    /// IMAP server hostname.
    var imapHost: String

    /// IMAP server port.
    var imapPort: Int

    /// SMTP server hostname.
    var smtpHost: String

    /// SMTP server port.
    var smtpPort: Int

    /// Authentication type (OAuth2 or password).
    var authType: AuthType

    /// Whether this account is enabled for sync.
    var isEnabled: Bool

    /// Last successful sync timestamp.
    var lastSyncAt: Date?

    /// Folders belonging to this account.
    @Relationship(deleteRule: .cascade, inverse: \Folder.account)
    var folders: [Folder]

    /// Creates a new account.
    init(
        id: UUID = UUID(),
        email: String,
        displayName: String? = nil,
        provider: AccountProvider = .custom,
        imapHost: String,
        imapPort: Int = AppConstants.IMAPPorts.ssl,
        smtpHost: String,
        smtpPort: Int = AppConstants.SMTPPorts.submission,
        authType: AuthType = .password,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.provider = provider
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.authType = authType
        self.isEnabled = isEnabled
        self.folders = []
    }
}

// MARK: - Account Provider

/// Supported email providers with pre-configured settings.
enum AccountProvider: String, Codable, CaseIterable {
    case gmail
    case outlook
    case icloud
    case yahoo
    case custom

    /// Display name for the provider.
    var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        case .icloud: return "iCloud"
        case .yahoo: return "Yahoo"
        case .custom: return "Other"
        }
    }

    /// SF Symbol icon name.
    var iconName: String {
        switch self {
        case .gmail: return "envelope.fill"
        case .outlook: return "envelope.fill"
        case .icloud: return "icloud.fill"
        case .yahoo: return "envelope.fill"
        case .custom: return "server.rack"
        }
    }

    /// Provider brand color.
    var color: Color {
        switch self {
        case .gmail: return .red
        case .outlook: return .blue
        case .icloud: return .cyan
        case .yahoo: return .purple
        case .custom: return .gray
        }
    }

    /// Whether this provider supports OAuth2.
    var supportsOAuth: Bool {
        switch self {
        case .gmail, .outlook:
            return true
        case .icloud, .yahoo, .custom:
            return false
        }
    }

    /// Default server configuration for this provider.
    var serverConfig: ServerConfig {
        switch self {
        case .gmail:
            return ServerConfig(
                imapHost: "imap.gmail.com",
                imapPort: 993,
                smtpHost: "smtp.gmail.com",
                smtpPort: 587
            )
        case .outlook:
            return ServerConfig(
                imapHost: "outlook.office365.com",
                imapPort: 993,
                smtpHost: "smtp.office365.com",
                smtpPort: 587
            )
        case .icloud:
            return ServerConfig(
                imapHost: "imap.mail.me.com",
                imapPort: 993,
                smtpHost: "smtp.mail.me.com",
                smtpPort: 587
            )
        case .yahoo:
            return ServerConfig(
                imapHost: "imap.mail.yahoo.com",
                imapPort: 993,
                smtpHost: "smtp.mail.yahoo.com",
                smtpPort: 587
            )
        case .custom:
            return ServerConfig(
                imapHost: "",
                imapPort: 993,
                smtpHost: "",
                smtpPort: 587
            )
        }
    }

    /// Detects provider from email domain.
    static func detect(from email: String) -> AccountProvider {
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""

        if domain.contains("gmail") || domain.contains("googlemail") {
            return .gmail
        } else if domain.contains("outlook") || domain.contains("hotmail") || domain.contains("live.com") {
            return .outlook
        } else if domain.contains("icloud") || domain.contains("me.com") || domain.contains("mac.com") {
            return .icloud
        } else if domain.contains("yahoo") {
            return .yahoo
        }

        return .custom
    }
}

/// Server configuration for an email provider.
struct ServerConfig {
    let imapHost: String
    let imapPort: Int
    let smtpHost: String
    let smtpPort: Int
}

// MARK: - Auth Type

/// Authentication method for email accounts.
enum AuthType: String, Codable {
    case oauth2
    case password
}
