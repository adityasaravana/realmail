import Foundation
import SwiftData
import os.log

/// ViewModel for managing mailbox state and sync operations.
@Observable
@MainActor
final class MailboxViewModel {
    // MARK: - State

    /// Currently selected folder.
    var selectedFolder: Folder?

    /// Currently selected message.
    var selectedMessage: Message?

    /// Whether a sync operation is in progress.
    private(set) var isSyncing = false

    /// Progress of the current sync (0.0 - 1.0).
    private(set) var syncProgress: Double = 0

    /// Last error that occurred.
    private(set) var lastError: Error?

    /// Whether the app is online.
    private(set) var isOnline = true

    // MARK: - Dependencies

    private let syncService = IMAPSyncService()
    private let logger = Logger.app

    // MARK: - Initialization

    init() {}

    // MARK: - Sync Operations

    /// Syncs all accounts.
    func syncAllAccounts(accounts: [Account], modelContext: ModelContext) async {
        guard !isSyncing else { return }

        isSyncing = true
        lastError = nil
        syncProgress = 0

        let accountProgress = 1.0 / Double(max(accounts.count, 1))

        for (index, account) in accounts.enumerated() where account.isEnabled {
            await syncService.syncAccount(account, modelContext: modelContext)
            syncProgress = Double(index + 1) * accountProgress
        }

        try? modelContext.save()
        isSyncing = false
        logger.info("All accounts synced")
    }

    /// Syncs a single account.
    func syncAccount(_ account: Account, modelContext: ModelContext) async {
        guard !isSyncing else { return }

        isSyncing = true
        lastError = nil

        await syncService.syncAccount(account, modelContext: modelContext)

        if let error = syncService.lastSyncError {
            lastError = error
        }

        syncProgress = syncService.syncProgress
        try? modelContext.save()
        isSyncing = false
    }

    /// Syncs the currently selected folder.
    func syncSelectedFolder(modelContext: ModelContext) async {
        guard let folder = selectedFolder else { return }
        guard !isSyncing else { return }

        isSyncing = true
        lastError = nil

        do {
            try await syncService.syncFolder(folder, modelContext: modelContext)
        } catch {
            lastError = error
        }

        isSyncing = false
    }

    // MARK: - Message Operations

    /// Marks the selected message as read/unread.
    func toggleReadStatus() async {
        guard let message = selectedMessage else { return }

        do {
            try await syncService.markAsRead(message, read: !message.isRead)
        } catch {
            lastError = error
            logger.error("Failed to toggle read status: \(error.localizedDescription)")
        }
    }

    /// Toggles the flagged status of the selected message.
    func toggleFlagged() async {
        guard let message = selectedMessage else { return }

        do {
            try await syncService.setFlagged(message, flagged: !message.isFlagged)
        } catch {
            lastError = error
            logger.error("Failed to toggle flag: \(error.localizedDescription)")
        }
    }

    /// Fetches the full body of the selected message.
    func fetchMessageBody() async {
        guard let message = selectedMessage else { return }
        guard message.bodyText == nil && message.bodyHtml == nil else { return }

        do {
            try await syncService.fetchBody(for: message)
        } catch {
            lastError = error
            logger.error("Failed to fetch body: \(error.localizedDescription)")
        }
    }

    /// Downloads an attachment.
    func downloadAttachment(_ attachment: Attachment) async {
        guard !attachment.isDownloaded else { return }

        do {
            try await syncService.downloadAttachment(attachment)
        } catch {
            lastError = error
            logger.error("Failed to download attachment: \(error.localizedDescription)")
        }
    }

    /// Moves the selected message to trash.
    func moveToTrash(modelContext: ModelContext) async {
        guard let message = selectedMessage,
              let folder = message.folder,
              let account = folder.account else { return }

        // Find trash folder
        guard let trashFolder = account.folders.first(where: { $0.folderType == .trash }) else {
            logger.warning("No trash folder found")
            return
        }

        // Move message
        message.folder?.messages.removeAll { $0.id == message.id }
        message.folder = trashFolder
        trashFolder.messages.append(message)

        // Update unread counts
        if !message.isRead {
            folder.unreadCount = max(0, folder.unreadCount - 1)
        }

        // Clear selection
        selectedMessage = nil

        // TODO: Sync with IMAP
    }

    /// Archives the selected message.
    func archive(modelContext: ModelContext) async {
        guard let message = selectedMessage,
              let folder = message.folder,
              let account = folder.account else { return }

        // Find archive folder
        guard let archiveFolder = account.folders.first(where: { $0.folderType == .archive }) else {
            logger.warning("No archive folder found")
            return
        }

        // Move message
        message.folder?.messages.removeAll { $0.id == message.id }
        message.folder = archiveFolder
        archiveFolder.messages.append(message)

        // Update unread counts
        if !message.isRead {
            folder.unreadCount = max(0, folder.unreadCount - 1)
        }

        // Clear selection
        selectedMessage = nil

        // TODO: Sync with IMAP
    }

    // MARK: - Navigation

    /// Selects the next message in the list.
    func selectNextMessage() {
        guard let folder = selectedFolder,
              let current = selectedMessage else {
            // Select first message
            selectedMessage = selectedFolder?.messages.first
            return
        }

        let messages = folder.messages.sorted { $0.date > $1.date }
        if let index = messages.firstIndex(where: { $0.id == current.id }),
           index < messages.count - 1 {
            selectedMessage = messages[index + 1]
        }
    }

    /// Selects the previous message in the list.
    func selectPreviousMessage() {
        guard let folder = selectedFolder,
              let current = selectedMessage else { return }

        let messages = folder.messages.sorted { $0.date > $1.date }
        if let index = messages.firstIndex(where: { $0.id == current.id }),
           index > 0 {
            selectedMessage = messages[index - 1]
        }
    }

    // MARK: - Cleanup

    /// Disconnects all sync connections.
    func disconnect() async {
        await syncService.disconnectAll()
    }
}

// MARK: - Compose ViewModel

/// ViewModel for composing email messages.
@Observable
@MainActor
final class ComposeViewModel {
    // MARK: - State

    var fromAccount: Account?
    var toRecipients: [EmailAddress] = []
    var ccRecipients: [EmailAddress] = []
    var bccRecipients: [EmailAddress] = []
    var subject: String = ""
    var bodyText: String = ""
    var bodyHtml: String?
    var attachments: [MessageComposer.AttachmentData] = []

    private(set) var isSending = false
    private(set) var sendError: Error?
    private(set) var isDraft = false

    // Reply context
    var replyToMessage: Message?
    var isReplyAll = false
    var isForward = false

    // MARK: - Dependencies

    private let sendQueue = SendQueueService()
    private let draftService = DraftService()
    private let logger = Logger.smtp

    // MARK: - Initialization

    init() {}

    /// Initializes for replying to a message.
    init(replyTo message: Message, replyAll: Bool = false, from account: Account) {
        self.replyToMessage = message
        self.isReplyAll = replyAll
        self.fromAccount = account

        // Set recipients
        if let replyAddress = EmailAddress(parsing: message.effectiveReplyTo) {
            toRecipients = [replyAddress]
        }

        if replyAll {
            let otherTos = message.toAddresses
                .compactMap { EmailAddress(parsing: $0) }
                .filter { $0.address != account.email }
            toRecipients.append(contentsOf: otherTos)

            ccRecipients = message.ccAddresses
                .compactMap { EmailAddress(parsing: $0) }
                .filter { $0.address != account.email }
        }

        // Set subject
        subject = message.subject.hasPrefix("Re:") ? message.subject : "Re: \(message.subject)"

        // Quote original message
        let quotedText = """

        On \(message.date.formatted()), \(message.formattedSender) wrote:
        > \(message.bodyText?.components(separatedBy: "\n").joined(separator: "\n> ") ?? "")
        """
        bodyText = quotedText
    }

    /// Initializes for forwarding a message.
    init(forward message: Message, from account: Account) {
        self.replyToMessage = message
        self.isForward = true
        self.fromAccount = account

        // Set subject
        subject = message.subject.hasPrefix("Fwd:") ? message.subject : "Fwd: \(message.subject)"

        // Build forwarded content
        bodyText = """


        ---------- Forwarded message ----------
        From: \(message.formattedSender) <\(message.fromAddress)>
        Date: \(message.date.formatted())
        Subject: \(message.subject)
        To: \(message.toAddresses.joined(separator: ", "))

        \(message.bodyText ?? "")
        """

        // Include attachments
        for attachment in message.attachments {
            if let content = attachment.content {
                attachments.append(MessageComposer.AttachmentData(
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    content: content
                ))
            }
        }
    }

    // MARK: - Actions

    /// Sends the composed message.
    func send() {
        guard let account = fromAccount else {
            sendError = ComposeError.noAccountSelected
            return
        }

        guard !toRecipients.isEmpty else {
            sendError = ComposeError.noRecipients
            return
        }

        isSending = true
        sendError = nil

        let message = MessageComposer.ComposedMessage(
            from: EmailAddress(name: account.displayName, address: account.email),
            to: toRecipients,
            cc: ccRecipients,
            bcc: bccRecipients,
            subject: subject,
            textBody: bodyText,
            htmlBody: bodyHtml,
            attachments: attachments,
            inReplyTo: replyToMessage?.messageId,
            references: replyToMessage?.references ?? []
        )

        _ = sendQueue.enqueue(message, account: account)

        isSending = false
        logger.info("Message queued for sending")
    }

    /// Saves as draft.
    func saveDraft(modelContext: ModelContext) {
        guard let account = fromAccount else { return }

        let message = MessageComposer.ComposedMessage(
            from: EmailAddress(name: account.displayName, address: account.email),
            to: toRecipients,
            cc: ccRecipients,
            bcc: bccRecipients,
            subject: subject,
            textBody: bodyText,
            htmlBody: bodyHtml,
            attachments: attachments
        )

        _ = draftService.saveDraft(message, account: account, modelContext: modelContext)
        isDraft = true
        logger.info("Draft saved")
    }

    /// Adds an attachment from a file URL.
    func addAttachment(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }

        let mimeType = mimeType(for: url)
        attachments.append(MessageComposer.AttachmentData(
            filename: url.lastPathComponent,
            mimeType: mimeType,
            content: data
        ))
    }

    /// Removes an attachment.
    func removeAttachment(at index: Int) {
        guard index < attachments.count else { return }
        attachments.remove(at: index)
    }

    // MARK: - Helpers

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let mimeTypes: [String: String] = [
            "pdf": "application/pdf",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt": "application/vnd.ms-powerpoint",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "txt": "text/plain",
            "html": "text/html",
            "zip": "application/zip",
        ]
        return mimeTypes[ext] ?? "application/octet-stream"
    }
}

// MARK: - Compose Errors

enum ComposeError: LocalizedError {
    case noAccountSelected
    case noRecipients

    var errorDescription: String? {
        switch self {
        case .noAccountSelected:
            return "Please select an account to send from."
        case .noRecipients:
            return "Please add at least one recipient."
        }
    }
}
