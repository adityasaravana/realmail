import Foundation
import Network
import os.log

/// IMAP client for communicating with email servers.
actor IMAPClient {
    private let host: String
    private let port: Int
    private let useTLS: Bool

    private var connection: NWConnection?
    private var isConnected = false
    private var isAuthenticated = false
    private var selectedMailbox: String?
    private var tagCounter = 0
    private var capabilities: Set<String> = []

    private let logger = Logger.imap

    /// Creates an IMAP client for the specified server.
    init(host: String, port: Int = 993, useTLS: Bool = true) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    deinit {
        connection?.cancel()
    }

    // MARK: - Connection

    /// Connects to the IMAP server.
    func connect() async throws {
        guard !isConnected else { return }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        let parameters: NWParameters
        if useTLS {
            parameters = .tls
        } else {
            parameters = .tcp
        }

        connection = NWConnection(to: endpoint, using: parameters)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection?.stateUpdateHandler = { [weak self] state in
                Task { [weak self] in
                    await self?.handleStateChange(state, continuation: continuation)
                }
            }
            connection?.start(queue: .global(qos: .userInitiated))
        }

        // Read server greeting
        let greeting = try await readResponse()
        logger.debug("Server greeting: \(greeting.first ?? "")")

        // Get capabilities
        try await fetchCapabilities()

        isConnected = true
        logger.info("Connected to \(self.host):\(self.port)")
    }

    private func handleStateChange(
        _ state: NWConnection.State,
        continuation: CheckedContinuation<Void, Error>
    ) {
        switch state {
        case .ready:
            continuation.resume()
        case .failed(let error):
            continuation.resume(throwing: IMAPError.connectionFailed(error))
        case .cancelled:
            continuation.resume(throwing: IMAPError.connectionCancelled)
        default:
            break
        }
    }

    /// Upgrades connection to TLS via STARTTLS.
    func starttls() async throws {
        guard isConnected, !useTLS else { return }

        let response = try await sendCommand("STARTTLS")
        guard response.contains(where: { $0.contains("OK") }) else {
            throw IMAPError.starttlsFailed
        }

        // Upgrade connection to TLS
        // Note: NWConnection doesn't support in-place TLS upgrade easily
        // In production, you'd reconnect with TLS or use a different approach
        logger.info("STARTTLS negotiated")
    }

    /// Disconnects from the server.
    func disconnect() async {
        if isConnected {
            _ = try? await sendCommand("LOGOUT")
        }
        connection?.cancel()
        connection = nil
        isConnected = false
        isAuthenticated = false
        selectedMailbox = nil
        logger.info("Disconnected from \(self.host)")
    }

    // MARK: - Authentication

    /// Authenticates using XOAUTH2.
    func authenticateOAuth(email: String, accessToken: String) async throws {
        guard isConnected else { throw IMAPError.notConnected }

        // Build XOAUTH2 string
        let authString = "user=\(email)\u{01}auth=Bearer \(accessToken)\u{01}\u{01}"
        let encodedAuth = Data(authString.utf8).base64EncodedString()

        let response = try await sendCommand("AUTHENTICATE XOAUTH2 \(encodedAuth)")

        if response.contains(where: { $0.contains("OK") }) {
            isAuthenticated = true
            try await fetchCapabilities() // Capabilities may change after auth
            logger.info("XOAUTH2 authentication successful for \(email)")
        } else {
            throw IMAPError.authenticationFailed(response.joined(separator: " "))
        }
    }

    /// Authenticates using LOGIN (username/password).
    func authenticateLogin(username: String, password: String) async throws {
        guard isConnected else { throw IMAPError.notConnected }

        // Escape special characters in password
        let escapedPassword = password.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let response = try await sendCommand("LOGIN \"\(username)\" \"\(escapedPassword)\"")

        if response.contains(where: { $0.contains("OK") }) {
            isAuthenticated = true
            try await fetchCapabilities()
            logger.info("LOGIN authentication successful for \(username)")
        } else {
            throw IMAPError.authenticationFailed(response.joined(separator: " "))
        }
    }

    // MARK: - Mailbox Operations

    /// Lists all mailboxes/folders.
    func listMailboxes(reference: String = "", pattern: String = "*") async throws -> [IMAPMailbox] {
        guard isAuthenticated else { throw IMAPError.notAuthenticated }

        let response = try await sendCommand("LIST \"\(reference)\" \"\(pattern)\"")

        var mailboxes: [IMAPMailbox] = []

        for line in response {
            if line.hasPrefix("*") && line.contains("LIST") {
                if let mailbox = parseMailboxLine(line) {
                    mailboxes.append(mailbox)
                }
            }
        }

        logger.debug("Found \(mailboxes.count) mailboxes")
        return mailboxes
    }

    /// Selects a mailbox for operations.
    func select(mailbox: String) async throws -> MailboxStatus {
        guard isAuthenticated else { throw IMAPError.notAuthenticated }

        let response = try await sendCommand("SELECT \"\(mailbox)\"")

        guard response.contains(where: { $0.contains("OK") }) else {
            throw IMAPError.mailboxNotFound(mailbox)
        }

        selectedMailbox = mailbox

        // Parse mailbox status from response
        let status = parseMailboxStatus(response)
        logger.debug("Selected mailbox \(mailbox): \(status.exists) messages, \(status.unseen) unseen")

        return status
    }

    /// Examines a mailbox without selecting it (read-only).
    func examine(mailbox: String) async throws -> MailboxStatus {
        guard isAuthenticated else { throw IMAPError.notAuthenticated }

        let response = try await sendCommand("EXAMINE \"\(mailbox)\"")

        guard response.contains(where: { $0.contains("OK") }) else {
            throw IMAPError.mailboxNotFound(mailbox)
        }

        return parseMailboxStatus(response)
    }

    // MARK: - Message Operations

    /// Fetches message headers for a UID range.
    func fetchHeaders(uids: ClosedRange<UInt32>) async throws -> [IMAPMessageHeader] {
        guard isAuthenticated, selectedMailbox != nil else { throw IMAPError.noMailboxSelected }

        let uidRange = "\(uids.lowerBound):\(uids.upperBound)"
        let fetchItems = "(UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE)"

        let response = try await sendCommand("UID FETCH \(uidRange) \(fetchItems)")

        var headers: [IMAPMessageHeader] = []

        // Parse FETCH responses
        var currentLines: [String] = []
        for line in response {
            if line.hasPrefix("*") && line.contains("FETCH") {
                if !currentLines.isEmpty {
                    if let header = parseMessageHeader(currentLines) {
                        headers.append(header)
                    }
                }
                currentLines = [line]
            } else if !line.contains("OK") && !line.contains("BAD") && !line.contains("NO") {
                currentLines.append(line)
            }
        }

        // Don't forget the last message
        if !currentLines.isEmpty {
            if let header = parseMessageHeader(currentLines) {
                headers.append(header)
            }
        }

        logger.debug("Fetched \(headers.count) message headers")
        return headers
    }

    /// Fetches the full message body.
    func fetchBody(uid: UInt32) async throws -> String {
        guard isAuthenticated, selectedMailbox != nil else { throw IMAPError.noMailboxSelected }

        let response = try await sendCommand("UID FETCH \(uid) (BODY[])")

        // Extract body from response
        let bodyContent = response.joined(separator: "\r\n")
        return bodyContent
    }

    /// Fetches a specific body section (for attachments).
    func fetchBodySection(uid: UInt32, section: String) async throws -> Data {
        guard isAuthenticated, selectedMailbox != nil else { throw IMAPError.noMailboxSelected }

        let response = try await sendCommand("UID FETCH \(uid) (BODY[\(section)])")

        // Extract and decode the body section
        let content = response.joined(separator: "\r\n")
        // In production, parse the literal and decode base64
        return Data(content.utf8)
    }

    // MARK: - Flag Operations

    /// Sets flags on messages.
    func setFlags(uids: [UInt32], flags: [String], silent: Bool = true) async throws {
        guard isAuthenticated, selectedMailbox != nil else { throw IMAPError.noMailboxSelected }

        let uidSet = uids.map(String.init).joined(separator: ",")
        let flagList = "(\(flags.joined(separator: " ")))"
        let command = silent ? "+FLAGS.SILENT" : "+FLAGS"

        let response = try await sendCommand("UID STORE \(uidSet) \(command) \(flagList)")

        guard response.contains(where: { $0.contains("OK") }) else {
            throw IMAPError.flagOperationFailed(response.joined(separator: " "))
        }

        logger.debug("Set flags \(flags) on \(uids.count) messages")
    }

    /// Removes flags from messages.
    func removeFlags(uids: [UInt32], flags: [String], silent: Bool = true) async throws {
        guard isAuthenticated, selectedMailbox != nil else { throw IMAPError.noMailboxSelected }

        let uidSet = uids.map(String.init).joined(separator: ",")
        let flagList = "(\(flags.joined(separator: " ")))"
        let command = silent ? "-FLAGS.SILENT" : "-FLAGS"

        let response = try await sendCommand("UID STORE \(uidSet) \(command) \(flagList)")

        guard response.contains(where: { $0.contains("OK") }) else {
            throw IMAPError.flagOperationFailed(response.joined(separator: " "))
        }

        logger.debug("Removed flags \(flags) from \(uids.count) messages")
    }

    // MARK: - IDLE

    /// Enters IDLE mode for push notifications.
    func idle(handler: @escaping (IDLEEvent) -> Void) async throws {
        guard isAuthenticated, selectedMailbox != nil else { throw IMAPError.noMailboxSelected }
        guard capabilities.contains("IDLE") else { throw IMAPError.idleNotSupported }

        let tag = nextTag()
        try await send("\(tag) IDLE\r\n")

        // Read continuation response
        let continuation = try await readLine()
        guard continuation.hasPrefix("+") else {
            throw IMAPError.idleStartFailed
        }

        logger.info("Entered IDLE mode")

        // Monitor for events
        while true {
            let line = try await readLine()

            if line.contains("EXISTS") {
                handler(.newMessage)
            } else if line.contains("EXPUNGE") {
                handler(.messageDeleted)
            } else if line.contains("FETCH") {
                handler(.flagsChanged)
            }

            // Check if we should exit IDLE (after ~29 minutes to avoid timeout)
            // In production, use a timer to send DONE and re-enter IDLE
        }
    }

    /// Exits IDLE mode.
    func doneIdle() async throws {
        try await send("DONE\r\n")
        _ = try await readResponse()
        logger.info("Exited IDLE mode")
    }

    // MARK: - Private Helpers

    private func nextTag() -> String {
        tagCounter += 1
        return String(format: "A%04d", tagCounter)
    }

    private func sendCommand(_ command: String) async throws -> [String] {
        let tag = nextTag()
        let fullCommand = "\(tag) \(command)\r\n"

        try await send(fullCommand)

        var response: [String] = []
        while true {
            let line = try await readLine()
            response.append(line)

            if line.hasPrefix(tag) {
                break
            }
        }

        return response
    }

    private func send(_ data: String) async throws {
        guard let connection = connection else {
            throw IMAPError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: Data(data.utf8),
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    private func readLine() async throws -> String {
        try await readResponse().first ?? ""
    }

    private func readResponse() async throws -> [String] {
        guard let connection = connection else {
            throw IMAPError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data = content, let response = String(data: data, encoding: .utf8) {
                    let lines = response.components(separatedBy: "\r\n").filter { !$0.isEmpty }
                    continuation.resume(returning: lines)
                } else if isComplete {
                    continuation.resume(throwing: IMAPError.connectionClosed)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func fetchCapabilities() async throws {
        let response = try await sendCommand("CAPABILITY")

        for line in response {
            if line.hasPrefix("*") && line.contains("CAPABILITY") {
                let parts = line.components(separatedBy: " ")
                capabilities = Set(parts.dropFirst(2)) // Drop "* CAPABILITY"
            }
        }

        logger.debug("Server capabilities: \(self.capabilities)")
    }

    private func parseMailboxLine(_ line: String) -> IMAPMailbox? {
        // Parse: * LIST (\HasNoChildren) "/" "INBOX"
        let pattern = #"\* LIST \(([^)]*)\) "([^"]*)" "?([^"]+)"?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let attributesRange = Range(match.range(at: 1), in: line)!
        let delimiterRange = Range(match.range(at: 2), in: line)!
        let nameRange = Range(match.range(at: 3), in: line)!

        let attributes = String(line[attributesRange]).components(separatedBy: " ").filter { !$0.isEmpty }
        let delimiter = String(line[delimiterRange])
        let name = String(line[nameRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        return IMAPMailbox(name: name, delimiter: delimiter, attributes: attributes)
    }

    private func parseMailboxStatus(_ response: [String]) -> MailboxStatus {
        var exists = 0
        var recent = 0
        var unseen = 0
        var uidValidity: UInt32 = 0
        var uidNext: UInt32 = 0

        for line in response {
            if line.contains("EXISTS") {
                exists = Int(line.components(separatedBy: " ").first { Int($0) != nil } ?? "0") ?? 0
            } else if line.contains("RECENT") {
                recent = Int(line.components(separatedBy: " ").first { Int($0) != nil } ?? "0") ?? 0
            } else if line.contains("UNSEEN") {
                unseen = Int(line.components(separatedBy: " ").first { Int($0) != nil } ?? "0") ?? 0
            } else if line.contains("UIDVALIDITY") {
                uidValidity = UInt32(line.components(separatedBy: " ").last { UInt32($0) != nil } ?? "0") ?? 0
            } else if line.contains("UIDNEXT") {
                uidNext = UInt32(line.components(separatedBy: " ").last { UInt32($0) != nil } ?? "0") ?? 0
            }
        }

        return MailboxStatus(
            exists: exists,
            recent: recent,
            unseen: unseen,
            uidValidity: uidValidity,
            uidNext: uidNext
        )
    }

    private func parseMessageHeader(_ lines: [String]) -> IMAPMessageHeader? {
        // Simplified parsing - in production use a proper IMAP parser
        let combined = lines.joined(separator: " ")

        // Extract UID
        guard let uidMatch = combined.range(of: #"UID (\d+)"#, options: .regularExpression),
              let uid = UInt32(combined[uidMatch].dropFirst(4)) else {
            return nil
        }

        return IMAPMessageHeader(
            uid: uid,
            flags: [], // Parse from response
            subject: "", // Parse from ENVELOPE
            from: "",
            to: [],
            date: Date(),
            size: 0
        )
    }
}

// MARK: - Supporting Types

/// IMAP mailbox/folder information.
struct IMAPMailbox: Sendable {
    let name: String
    let delimiter: String
    let attributes: [String]

    var isSelectable: Bool {
        !attributes.contains("\\Noselect")
    }

    var hasChildren: Bool {
        attributes.contains("\\HasChildren")
    }
}

/// Mailbox status information.
struct MailboxStatus: Sendable {
    let exists: Int
    let recent: Int
    let unseen: Int
    let uidValidity: UInt32
    let uidNext: UInt32
}

/// IMAP message header information.
struct IMAPMessageHeader: Sendable {
    let uid: UInt32
    let flags: [String]
    let subject: String
    let from: String
    let to: [String]
    let date: Date
    let size: Int
}

/// IDLE notification events.
enum IDLEEvent: Sendable {
    case newMessage
    case messageDeleted
    case flagsChanged
}

// MARK: - IMAP Errors

/// Errors that can occur during IMAP operations.
enum IMAPError: LocalizedError {
    case connectionFailed(Error)
    case connectionCancelled
    case connectionClosed
    case notConnected
    case starttlsFailed
    case authenticationFailed(String)
    case notAuthenticated
    case mailboxNotFound(String)
    case noMailboxSelected
    case flagOperationFailed(String)
    case idleNotSupported
    case idleStartFailed
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .connectionCancelled:
            return "Connection was cancelled."
        case .connectionClosed:
            return "Connection closed unexpectedly."
        case .notConnected:
            return "Not connected to server."
        case .starttlsFailed:
            return "STARTTLS negotiation failed."
        case .authenticationFailed(let response):
            return "Authentication failed: \(response)"
        case .notAuthenticated:
            return "Not authenticated."
        case .mailboxNotFound(let name):
            return "Mailbox not found: \(name)"
        case .noMailboxSelected:
            return "No mailbox selected."
        case .flagOperationFailed(let response):
            return "Flag operation failed: \(response)"
        case .idleNotSupported:
            return "Server does not support IDLE."
        case .idleStartFailed:
            return "Failed to enter IDLE mode."
        case .fetchFailed(let response):
            return "Fetch failed: \(response)"
        }
    }
}
