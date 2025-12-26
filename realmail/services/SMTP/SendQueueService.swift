import Foundation
import SwiftData
import os.log
import Network

/// Service for queuing and sending email messages with retry logic.
@Observable
final class SendQueueService {
    /// Current queue state for UI.
    private(set) var queuedCount = 0
    private(set) var isSending = false
    private(set) var lastError: Error?

    private let authService = AuthService.shared
    private let logger = Logger.smtp

    private var queue: [QueuedMessage] = []
    private var sendTask: Task<Void, Never>?
    private var networkMonitor: NWPathMonitor?
    private var isOnline = true

    init() {
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor?.cancel()
        sendTask?.cancel()
    }

    // MARK: - Queue Management

    /// Enqueues a message for sending.
    func enqueue(
        _ message: MessageComposer.ComposedMessage,
        account: Account,
        saveToDrafts: Bool = false
    ) -> UUID {
        let queuedMessage = QueuedMessage(
            id: UUID(),
            message: message,
            account: account,
            status: .pending,
            retryCount: 0,
            createdAt: Date()
        )

        queue.append(queuedMessage)
        queuedCount = queue.count
        logger.info("Message queued for \(message.to.first?.address ?? "unknown")")

        // Start processing if not already running
        processQueue()

        return queuedMessage.id
    }

    /// Cancels a queued message.
    func cancel(messageId: UUID) {
        queue.removeAll { $0.id == messageId }
        queuedCount = queue.count
        logger.debug("Message \(messageId) cancelled")
    }

    /// Gets the status of a queued message.
    func status(of messageId: UUID) -> QueuedMessageStatus? {
        queue.first { $0.id == messageId }?.status
    }

    // MARK: - Queue Processing

    private func processQueue() {
        guard sendTask == nil else { return }

        sendTask = Task {
            while !queue.isEmpty {
                guard isOnline else {
                    logger.debug("Offline, waiting for network...")
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }

                // Get next pending message
                guard let index = queue.firstIndex(where: { $0.status == .pending }) else {
                    break
                }

                var message = queue[index]
                message.status = .sending
                queue[index] = message

                isSending = true

                do {
                    try await sendMessage(message)

                    // Success - remove from queue
                    queue.remove(at: index)
                    queuedCount = queue.count
                    logger.info("Message sent successfully to \(message.message.to.first?.address ?? "unknown")")

                } catch {
                    await handleSendError(error, for: &message, at: index)
                }

                isSending = false
            }

            sendTask = nil
        }
    }

    private func sendMessage(_ queuedMessage: QueuedMessage) async throws {
        let account = queuedMessage.account
        let message = queuedMessage.message

        // Create SMTP client
        let client = SMTPClient(
            host: account.smtpHost,
            port: account.smtpPort,
            useTLS: account.smtpPort == 465
        )

        // Connect
        try await client.connect()

        // Authenticate
        switch account.authType {
        case .oauth2:
            let credentials = try await authService.getValidCredentials(for: account.email)
            try await client.authenticateOAuth(email: account.email, accessToken: credentials.accessToken)
        case .password:
            let password = try await authService.getPassword(for: account.email)
            try await client.authenticateLogin(username: account.email, password: password)
        }

        // Compose MIME message
        let mimeMessage = MessageComposer.compose(message)

        // Send
        let result = try await client.send(
            from: message.from.address,
            to: message.allRecipients,
            data: mimeMessage
        )

        // Copy to Sent folder via IMAP
        try await copyToSent(mimeMessage: mimeMessage, account: account)

        // Disconnect
        await client.disconnect()
    }

    private func handleSendError(_ error: Error, for message: inout QueuedMessage, at index: Int) async {
        message.retryCount += 1
        message.lastError = error.localizedDescription

        let maxRetries = 3

        if isTransientError(error) && message.retryCount < maxRetries {
            // Retry with exponential backoff
            message.status = .retrying
            queue[index] = message

            let delay = pow(2.0, Double(message.retryCount))
            logger.warning("Send failed, retrying in \(delay)s: \(error.localizedDescription)")

            try? await Task.sleep(for: .seconds(delay))

            message.status = .pending
            queue[index] = message

        } else {
            // Permanent failure
            message.status = .failed
            queue[index] = message
            lastError = error

            logger.error("Send failed permanently: \(error.localizedDescription)")

            // Notify user
            await notifyFailure(message: message, error: error)
        }
    }

    private func isTransientError(_ error: Error) -> Bool {
        // Network errors are transient
        if error is NWError {
            return true
        }

        // SMTP temporary errors (4xx)
        if let smtpError = error as? SMTPError {
            switch smtpError {
            case .connectionFailed, .connectionClosed:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func copyToSent(mimeMessage: String, account: Account) async throws {
        // TODO: Use IMAP APPEND to copy message to Sent folder
        // This ensures sent messages appear in the Sent folder
        logger.debug("Would copy message to Sent folder for \(account.email)")
    }

    private func notifyFailure(message: QueuedMessage, error: Error) async {
        // TODO: Show user notification about send failure
        logger.error("Should notify user about send failure")
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()

        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied

                if wasOffline && self?.isOnline == true {
                    self?.logger.info("Network restored, resuming queue processing")
                    self?.processQueue()
                }
            }
        }

        networkMonitor?.start(queue: .global(qos: .utility))
    }

    // MARK: - Retry All Failed

    /// Retries all failed messages.
    func retryAllFailed() {
        for i in queue.indices where queue[i].status == .failed {
            queue[i].status = .pending
            queue[i].retryCount = 0
        }

        processQueue()
    }

    /// Clears all failed messages from the queue.
    func clearFailed() {
        queue.removeAll { $0.status == .failed }
        queuedCount = queue.count
        lastError = nil
    }
}

// MARK: - Queued Message

/// A message in the send queue.
struct QueuedMessage: Identifiable, Sendable {
    let id: UUID
    let message: MessageComposer.ComposedMessage
    let account: Account
    var status: QueuedMessageStatus
    var retryCount: Int
    let createdAt: Date
    var lastError: String?
}

/// Status of a queued message.
enum QueuedMessageStatus: Sendable {
    case pending
    case sending
    case retrying
    case sent
    case failed
}

// MARK: - Draft Service

/// Service for managing email drafts.
@Observable
final class DraftService {
    private let logger = Logger.smtp

    /// Saves a draft message.
    @MainActor
    func saveDraft(
        _ message: MessageComposer.ComposedMessage,
        account: Account,
        modelContext: ModelContext
    ) -> Message {
        // Create a Message object for the draft
        let draft = Message(
            uid: 0, // Local draft, no UID yet
            subject: message.subject,
            fromAddress: message.from.address,
            fromName: message.from.name,
            toAddresses: message.to.map(\.address),
            ccAddresses: message.cc.map(\.address),
            bccAddresses: message.bcc.map(\.address),
            date: Date(),
            bodyText: message.textBody,
            bodyHtml: message.htmlBody,
            isDraft: true
        )

        // Find or create Drafts folder
        if let draftsFolder = account.folders.first(where: { $0.folderType == .drafts }) {
            draft.folder = draftsFolder
            draftsFolder.messages.append(draft)
        }

        modelContext.insert(draft)
        logger.debug("Draft saved: \(message.subject)")

        return draft
    }

    /// Loads a draft for continued editing.
    func loadDraft(_ draft: Message) -> MessageComposer.ComposedMessage {
        MessageComposer.ComposedMessage(
            from: EmailAddress(name: draft.fromName, address: draft.fromAddress),
            to: draft.toAddresses.compactMap { EmailAddress(parsing: $0) },
            cc: draft.ccAddresses.compactMap { EmailAddress(parsing: $0) },
            bcc: draft.bccAddresses.compactMap { EmailAddress(parsing: $0) },
            subject: draft.subject,
            textBody: draft.bodyText,
            htmlBody: draft.bodyHtml,
            attachments: draft.attachments.compactMap { att in
                guard let content = att.content else { return nil }
                return MessageComposer.AttachmentData(
                    filename: att.filename,
                    mimeType: att.mimeType,
                    content: content,
                    isInline: att.disposition == .inline,
                    contentId: att.contentId
                )
            }
        )
    }

    /// Deletes a draft.
    @MainActor
    func deleteDraft(_ draft: Message, modelContext: ModelContext) {
        modelContext.delete(draft)
        logger.debug("Draft deleted: \(draft.subject)")

        // TODO: Also delete from IMAP Drafts folder if synced
    }

    /// Syncs drafts with IMAP Drafts folder.
    func syncDrafts(for account: Account) async throws {
        // TODO: Use IMAP to sync drafts
        logger.debug("Would sync drafts for \(account.email)")
    }
}
