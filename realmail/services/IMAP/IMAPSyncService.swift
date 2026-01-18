import Foundation
import SwiftData
import os.log

/// Service for synchronizing email via IMAP.
@Observable
final class IMAPSyncService {
    /// Sync state for UI updates.
    private(set) var isSyncing = false
    private(set) var syncProgress: Double = 0
    private(set) var lastSyncError: Error?

    private let authService = AuthService.shared
    private let logger = Logger.imap

    private var activeClients: [UUID: IMAPClient] = [:]

    // MARK: - Sync Operations

    /// Performs full sync for an account.
    @MainActor
    func syncAccount(_ account: Account, modelContext: ModelContext) async {
        guard !isSyncing else { return }

        isSyncing = true
        syncProgress = 0
        lastSyncError = nil

        do {
            // Get or create IMAP client
            let client = try await getClient(for: account)

            // Connect and authenticate
            try await client.connect()
            try await authenticate(client: client, account: account)

            // Sync folders
            try await syncFolders(client: client, account: account, modelContext: modelContext)
            syncProgress = 0.2

            // Sync messages in each folder
            let folders = account.folders.sorted { $0.sortOrder < $1.sortOrder }
            let folderProgress = 0.8 / Double(max(folders.count, 1))

            for (index, folder) in folders.enumerated() {
                if folder.folderType != .trash && folder.folderType != .spam {
                    try await syncMessages(client: client, folder: folder, modelContext: modelContext)
                }
                syncProgress = 0.2 + (Double(index + 1) * folderProgress)
            }

            // Update last sync time
            account.lastSyncAt = Date()
            try modelContext.save()

            syncProgress = 1.0
            logger.info("Sync completed for \(account.email)")

        } catch {
            lastSyncError = error
            logger.error("Sync failed for \(account.email): \(error.localizedDescription)")
        }

        isSyncing = false
    }

    /// Syncs a single folder.
    @MainActor
    func syncFolder(_ folder: Folder, modelContext: ModelContext) async throws {
        guard let account = folder.account else { return }

        let client = try await getClient(for: account)
        try await client.connect()
        try await authenticate(client: client, account: account)
        try await syncMessages(client: client, folder: folder, modelContext: modelContext)

        try modelContext.save()
    }

    /// Fetches new messages using IDLE or poll.
    func checkNewMessages(for account: Account, modelContext: ModelContext) async throws {
        let client = try await getClient(for: account)

        // Find inbox folder
        guard let inbox = account.folders.first(where: { $0.folderType == .inbox }) else {
            return
        }

        let status = try await client.select(mailbox: inbox.path)

        // Check if there are new messages
        if status.exists > inbox.totalCount {
            // Fetch new message headers
            let startUID = UInt32(inbox.totalCount + 1)
            let endUID = UInt32(status.exists)

            if startUID <= endUID {
                let headers = try await client.fetchHeaders(uids: startUID...endUID)

                await MainActor.run {
                    for header in headers {
                        let message = createMessage(from: header, folder: inbox)
                        modelContext.insert(message)
                    }

                    inbox.totalCount = status.exists
                    inbox.unreadCount = status.unseen
                }
            }
        }
    }

    /// Starts IDLE monitoring for an account.
    func startIDLE(for account: Account, onNewMessage: @escaping () -> Void) async throws {
        let client = try await getClient(for: account)

        guard let inbox = account.folders.first(where: { $0.folderType == .inbox }) else {
            return
        }

        _ = try await client.select(mailbox: inbox.path)

        try await client.idle { event in
            switch event {
            case .newMessage:
                onNewMessage()
            case .messageDeleted, .flagsChanged:
                // Handle other events
                break
            }
        }
    }

    // MARK: - Private Methods

    private func getClient(for account: Account) async throws -> IMAPClient {
        if let client = activeClients[account.id] {
            return client
        }

        let client = IMAPClient(
            host: account.imapHost,
            port: account.imapPort,
            useTLS: account.imapPort == 993
        )

        activeClients[account.id] = client
        return client
    }

    private func authenticate(client: IMAPClient, account: Account) async throws {
        switch account.authType {
        case .oauth2:
            let credentials = try await authService.getValidCredentials(for: account.email)
            try await client.authenticateOAuth(email: account.email, accessToken: credentials.accessToken)

        case .password:
            let password = try await authService.getPassword(for: account.email)
            try await client.authenticateLogin(username: account.email, password: password)
        }
    }

    private func syncFolders(
        client: IMAPClient,
        account: Account,
        modelContext: ModelContext
    ) async throws {
        let imapFolders = try await client.listMailboxes()

        // Map existing folders by path
        var existingFolders: [String: Folder] = [:]
        for folder in account.folders {
            existingFolders[folder.path] = folder
        }

        // Update or create folders
        for imapFolder in imapFolders {
            guard imapFolder.isSelectable else { continue }

            if let existing = existingFolders[imapFolder.name] {
                // Update existing folder
                existingFolders.removeValue(forKey: imapFolder.name)
            } else {
                // Create new folder
                let folderType = FolderType.detect(from: imapFolder.attributes, name: imapFolder.name)
                let folder = Folder(
                    name: imapFolder.name.components(separatedBy: imapFolder.delimiter).last ?? imapFolder.name,
                    path: imapFolder.name,
                    folderType: folderType,
                    sortOrder: folderType.defaultSortOrder,
                    account: account
                )

                modelContext.insert(folder)
                account.folders.append(folder)

                logger.debug("Created folder: \(folder.name) (\(folder.folderType.rawValue))")
            }
        }

        // Remove deleted folders
        for (_, folder) in existingFolders {
            modelContext.delete(folder)
            logger.debug("Deleted folder: \(folder.name)")
        }
    }

    private func syncMessages(
        client: IMAPClient,
        folder: Folder,
        modelContext: ModelContext
    ) async throws {
        let status = try await client.select(mailbox: folder.path)

        // Update folder counts
        folder.totalCount = status.exists
        folder.uidValidity = status.uidValidity

        // Determine UIDs to fetch
        let existingUIDs = Set(folder.messages.map(\.uid))
        let highestExistingUID = existingUIDs.max() ?? 0

        // Fetch new messages
        if status.uidNext > highestExistingUID + 1 {
            let startUID = highestExistingUID + 1
            let endUID = status.uidNext - 1

            let headers = try await client.fetchHeaders(uids: startUID...endUID)

            for header in headers {
                if !existingUIDs.contains(header.uid) {
                    let message = createMessage(from: header, folder: folder)
                    modelContext.insert(message)
                    folder.messages.append(message)
                }
            }

            logger.debug("Fetched \(headers.count) new messages in \(folder.name)")
        }

        // Update unread count
        folder.unreadCount = folder.messages.filter { !$0.isRead }.count
    }

    private func createMessage(from header: IMAPMessageHeader, folder: Folder) -> Message {
        let message = Message(
            uid: header.uid,
            subject: header.subject,
            fromAddress: header.from,
            toAddresses: header.to,
            date: header.date,
            isRead: header.flags.contains("\\Seen"),
            isFlagged: header.flags.contains("\\Flagged"),
            isDraft: header.flags.contains("\\Draft"),
            isAnswered: header.flags.contains("\\Answered"),
            flags: header.flags,
            size: header.size,
            folder: folder
        )

        // Generate snippet from subject if body not available
        message.snippet = String(header.subject.prefix(100))

        return message
    }

    // MARK: - Flag Operations

    /// Marks a message as read/unread on the server.
    func markAsRead(_ message: Message, read: Bool) async throws {
        guard let folder = message.folder,
              let account = folder.account else { return }

        let client = try await getClient(for: account)
        _ = try await client.select(mailbox: folder.path)

        if read {
            try await client.setFlags(uids: [message.uid], flags: ["\\Seen"])
        } else {
            try await client.removeFlags(uids: [message.uid], flags: ["\\Seen"])
        }

        message.markAsRead(read)
        logger.debug("Marked message \(message.uid) as \(read ? "read" : "unread")")
    }

    /// Flags/unflags a message on the server.
    func setFlagged(_ message: Message, flagged: Bool) async throws {
        guard let folder = message.folder,
              let account = folder.account else { return }

        let client = try await getClient(for: account)
        _ = try await client.select(mailbox: folder.path)

        if flagged {
            try await client.setFlags(uids: [message.uid], flags: ["\\Flagged"])
        } else {
            try await client.removeFlags(uids: [message.uid], flags: ["\\Flagged"])
        }

        message.setFlagged(flagged)
        logger.debug("Set flagged=\(flagged) on message \(message.uid)")
    }

    // MARK: - Body Fetching

    /// Fetches the full body of a message.
    func fetchBody(for message: Message) async throws {
        guard let folder = message.folder,
              let account = folder.account else { return }

        let client = try await getClient(for: account)
        _ = try await client.select(mailbox: folder.path)

        let body = try await client.fetchBody(uid: message.uid)

        // Parse MIME body
        let parsed = MIMEParser.parse(body)
        message.bodyText = parsed.textBody
        message.bodyHtml = parsed.htmlBody
        message.snippet = String((parsed.textBody ?? "").prefix(200))

        // Create attachments
        for attachment in parsed.attachments {
            let att = Attachment(
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                size: attachment.size,
                contentId: attachment.contentId,
                disposition: attachment.isInline ? .inline : .attachment,
                bodySection: attachment.bodySection,
                message: message
            )
            message.attachments.append(att)
        }

        message.hasAttachments = !message.attachments.isEmpty
        logger.debug("Fetched body for message \(message.uid)")
    }

    /// Downloads an attachment's content.
    func downloadAttachment(_ attachment: Attachment) async throws {
        guard let message = attachment.message,
              let folder = message.folder,
              let account = folder.account,
              let section = attachment.bodySection else { return }

        let client = try await getClient(for: account)
        _ = try await client.select(mailbox: folder.path)

        let data = try await client.fetchBodySection(uid: message.uid, section: section)
        attachment.content = data
        attachment.isDownloaded = true

        logger.debug("Downloaded attachment: \(attachment.filename)")
    }

    // MARK: - Cleanup

    /// Disconnects all active clients.
    func disconnectAll() async {
        for (_, client) in activeClients {
            await client.disconnect()
        }
        activeClients.removeAll()
    }
}

// MARK: - MIME Parser

/// Simple MIME message parser.
enum MIMEParser {
    struct ParsedMessage {
        var textBody: String?
        var htmlBody: String?
        var attachments: [ParsedAttachment] = []
    }

    struct ParsedAttachment {
        let filename: String
        let mimeType: String
        let size: Int
        let contentId: String?
        let isInline: Bool
        let bodySection: String
    }

    static func parse(_ rawMessage: String) -> ParsedMessage {
        // Simplified MIME parsing - in production use a proper MIME library
        var result = ParsedMessage()

        // Extract content-type
        let isMultipart = rawMessage.lowercased().contains("content-type: multipart")

        if isMultipart {
            // Parse multipart message
            // This is a simplified implementation
            if let textRange = rawMessage.range(of: "Content-Type: text/plain", options: .caseInsensitive) {
                // Extract plain text part
                let textStart = rawMessage[textRange.upperBound...]
                if let endRange = textStart.range(of: "--", options: []) {
                    result.textBody = String(textStart[..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if let htmlRange = rawMessage.range(of: "Content-Type: text/html", options: .caseInsensitive) {
                // Extract HTML part
                let htmlStart = rawMessage[htmlRange.upperBound...]
                if let endRange = htmlStart.range(of: "--", options: []) {
                    result.htmlBody = String(htmlStart[..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } else {
            // Simple message
            if let bodyStart = rawMessage.range(of: "\r\n\r\n") {
                result.textBody = String(rawMessage[bodyStart.upperBound...])
            }
        }

        return result
    }
}
