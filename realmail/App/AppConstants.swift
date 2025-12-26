import Foundation

/// Application-wide constants and configuration values.
enum AppConstants {
    /// Application identifier used for Keychain and logging.
    static let appIdentifier = "com.realmail.app"

    /// Keychain service identifier for credential storage.
    static let keychainService = "com.realmail.credentials"

    /// Maximum attachment size in bytes (25 MB).
    static let maxAttachmentSize: Int64 = 25 * 1024 * 1024

    /// Default IMAP ports.
    enum IMAPPorts {
        static let ssl = 993
        static let plain = 143
    }

    /// Default SMTP ports.
    enum SMTPPorts {
        static let ssl = 465
        static let submission = 587
        static let plain = 25
    }

    /// Sync configuration.
    enum Sync {
        /// Default number of messages to fetch per batch.
        static let batchSize = 50

        /// IDLE timeout before reconnecting (25 minutes).
        static let idleTimeoutSeconds: TimeInterval = 25 * 60

        /// Automatic sync interval (5 minutes).
        static let autoSyncIntervalSeconds: TimeInterval = 5 * 60
    }

    /// Cache configuration.
    enum Cache {
        /// Maximum message body cache size (100 MB).
        static let maxBodyCacheSize: Int64 = 100 * 1024 * 1024

        /// Maximum attachment cache size (500 MB).
        static let maxAttachmentCacheSize: Int64 = 500 * 1024 * 1024
    }

    /// UI constants.
    enum UI {
        /// Sidebar minimum width.
        static let sidebarMinWidth: CGFloat = 200

        /// Message list minimum width.
        static let messageListMinWidth: CGFloat = 300

        /// Detail pane minimum width.
        static let detailMinWidth: CGFloat = 400

        /// Message snippet length.
        static let snippetLength = 150
    }
}
