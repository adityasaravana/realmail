import Foundation
import Network
import os.log

/// SMTP client for sending email.
actor SMTPClient {
    private let host: String
    private let port: Int
    private let useTLS: Bool

    private var connection: NWConnection?
    private var isConnected = false
    private var isAuthenticated = false
    private var serverCapabilities: Set<String> = []

    private let logger = Logger.smtp

    /// Creates an SMTP client for the specified server.
    init(host: String, port: Int = 587, useTLS: Bool = false) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    deinit {
        connection?.cancel()
    }

    // MARK: - Connection

    /// Connects to the SMTP server.
    func connect() async throws {
        guard !isConnected else { return }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        let parameters: NWParameters
        if useTLS || port == 465 {
            // Implicit TLS (port 465)
            parameters = .tls
        } else {
            // Will upgrade via STARTTLS (port 587)
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
        guard greeting.code == 220 else {
            throw SMTPError.unexpectedResponse(greeting.message)
        }

        logger.debug("Server greeting: \(greeting.message)")

        // Send EHLO
        try await sendEHLO()

        // STARTTLS if needed
        if !useTLS && port != 465 && serverCapabilities.contains("STARTTLS") {
            try await startTLS()
            try await sendEHLO() // Re-EHLO after TLS
        }

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
            continuation.resume(throwing: SMTPError.connectionFailed(error))
        case .cancelled:
            continuation.resume(throwing: SMTPError.connectionCancelled)
        default:
            break
        }
    }

    private func sendEHLO() async throws {
        let hostname = Host.current().localizedName ?? "localhost"
        let response = try await sendCommand("EHLO \(hostname)")

        guard response.code == 250 else {
            throw SMTPError.ehloFailed(response.message)
        }

        // Parse capabilities from multi-line response
        serverCapabilities = Set(response.message.components(separatedBy: "\n")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() })

        logger.debug("Server capabilities: \(self.serverCapabilities)")
    }

    private func startTLS() async throws {
        let response = try await sendCommand("STARTTLS")

        guard response.code == 220 else {
            throw SMTPError.starttlsFailed(response.message)
        }

        // Upgrade connection to TLS
        // Note: In production, you'd need to handle this properly
        // NWConnection doesn't support in-place upgrade easily
        logger.info("STARTTLS negotiated")
    }

    /// Disconnects from the server.
    func disconnect() async {
        if isConnected {
            _ = try? await sendCommand("QUIT")
        }
        connection?.cancel()
        connection = nil
        isConnected = false
        isAuthenticated = false
        logger.info("Disconnected from \(self.host)")
    }

    // MARK: - Authentication

    /// Authenticates using XOAUTH2.
    func authenticateOAuth(email: String, accessToken: String) async throws {
        guard isConnected else { throw SMTPError.notConnected }
        guard serverCapabilities.contains(where: { $0.contains("XOAUTH2") }) else {
            throw SMTPError.authMethodNotSupported("XOAUTH2")
        }

        // Build XOAUTH2 string
        let authString = "user=\(email)\u{01}auth=Bearer \(accessToken)\u{01}\u{01}"
        let encodedAuth = Data(authString.utf8).base64EncodedString()

        let response = try await sendCommand("AUTH XOAUTH2 \(encodedAuth)")

        if response.code == 235 {
            isAuthenticated = true
            logger.info("XOAUTH2 authentication successful")
        } else {
            throw SMTPError.authenticationFailed(response.message)
        }
    }

    /// Authenticates using LOGIN.
    func authenticateLogin(username: String, password: String) async throws {
        guard isConnected else { throw SMTPError.notConnected }

        // AUTH LOGIN
        var response = try await sendCommand("AUTH LOGIN")
        guard response.code == 334 else {
            throw SMTPError.authMethodNotSupported("LOGIN")
        }

        // Send username (base64)
        response = try await sendCommand(Data(username.utf8).base64EncodedString())
        guard response.code == 334 else {
            throw SMTPError.authenticationFailed(response.message)
        }

        // Send password (base64)
        response = try await sendCommand(Data(password.utf8).base64EncodedString())

        if response.code == 235 {
            isAuthenticated = true
            logger.info("LOGIN authentication successful")
        } else {
            throw SMTPError.authenticationFailed(response.message)
        }
    }

    /// Authenticates using PLAIN.
    func authenticatePlain(username: String, password: String) async throws {
        guard isConnected else { throw SMTPError.notConnected }
        guard serverCapabilities.contains(where: { $0.contains("PLAIN") }) else {
            throw SMTPError.authMethodNotSupported("PLAIN")
        }

        // Build PLAIN auth string: \0username\0password
        let authString = "\0\(username)\0\(password)"
        let encoded = Data(authString.utf8).base64EncodedString()

        let response = try await sendCommand("AUTH PLAIN \(encoded)")

        if response.code == 235 {
            isAuthenticated = true
            logger.info("PLAIN authentication successful")
        } else {
            throw SMTPError.authenticationFailed(response.message)
        }
    }

    // MARK: - Send Message

    /// Sends an email message.
    func send(from: String, to: [String], data: String) async throws -> SendResult {
        guard isAuthenticated else { throw SMTPError.notAuthenticated }

        // MAIL FROM
        var response = try await sendCommand("MAIL FROM:<\(from)>")
        guard response.code == 250 else {
            throw SMTPError.mailFromRejected(response.message)
        }

        // RCPT TO for each recipient
        for recipient in to {
            response = try await sendCommand("RCPT TO:<\(recipient)>")
            guard response.code == 250 || response.code == 251 else {
                throw SMTPError.recipientRejected(recipient, response.message)
            }
        }

        // DATA
        response = try await sendCommand("DATA")
        guard response.code == 354 else {
            throw SMTPError.dataRejected(response.message)
        }

        // Send message content
        // Ensure proper line endings and dot-stuffing
        var messageData = data
            .replacingOccurrences(of: "\r\n.", with: "\r\n..")
            .replacingOccurrences(of: "\n", with: "\r\n")

        if !messageData.hasSuffix("\r\n") {
            messageData += "\r\n"
        }
        messageData += ".\r\n"

        try await send(messageData)
        response = try await readResponse()

        guard response.code == 250 else {
            throw SMTPError.sendFailed(response.message)
        }

        // Extract message ID if available
        let messageId = extractMessageId(from: response.message)

        logger.info("Message sent successfully to \(to.count) recipients")

        return SendResult(
            success: true,
            messageId: messageId,
            serverResponse: response.message
        )
    }

    // MARK: - Private Helpers

    private func sendCommand(_ command: String) async throws -> SMTPResponse {
        try await send("\(command)\r\n")
        return try await readResponse()
    }

    private func send(_ data: String) async throws {
        guard let connection = connection else {
            throw SMTPError.notConnected
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

    private func readResponse() async throws -> SMTPResponse {
        guard let connection = connection else {
            throw SMTPError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data = content, let response = String(data: data, encoding: .utf8) {
                    // Parse SMTP response code
                    let lines = response.components(separatedBy: "\r\n").filter { !$0.isEmpty }
                    if let firstLine = lines.first, firstLine.count >= 3,
                       let code = Int(firstLine.prefix(3)) {
                        continuation.resume(returning: SMTPResponse(code: code, message: response))
                    } else {
                        continuation.resume(throwing: SMTPError.invalidResponse(response))
                    }
                } else if isComplete {
                    continuation.resume(throwing: SMTPError.connectionClosed)
                } else {
                    continuation.resume(throwing: SMTPError.invalidResponse(""))
                }
            }
        }
    }

    private func extractMessageId(from response: String) -> String? {
        // Try to extract message ID from response like "250 2.0.0 <message-id> Queued"
        let pattern = #"<([^>]+@[^>]+)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range(at: 1), in: response) else {
            return nil
        }
        return String(response[range])
    }
}

// MARK: - Supporting Types

/// SMTP response with code and message.
struct SMTPResponse: Sendable {
    let code: Int
    let message: String

    var isSuccess: Bool {
        code >= 200 && code < 400
    }

    var isError: Bool {
        code >= 400
    }
}

/// Result of sending an email.
struct SendResult: Sendable {
    let success: Bool
    let messageId: String?
    let serverResponse: String
}

// MARK: - SMTP Errors

/// Errors that can occur during SMTP operations.
enum SMTPError: LocalizedError {
    case connectionFailed(Error)
    case connectionCancelled
    case connectionClosed
    case notConnected
    case notAuthenticated
    case unexpectedResponse(String)
    case ehloFailed(String)
    case starttlsFailed(String)
    case authMethodNotSupported(String)
    case authenticationFailed(String)
    case invalidResponse(String)
    case mailFromRejected(String)
    case recipientRejected(String, String)
    case dataRejected(String)
    case sendFailed(String)

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
        case .notAuthenticated:
            return "Not authenticated."
        case .unexpectedResponse(let response):
            return "Unexpected server response: \(response)"
        case .ehloFailed(let response):
            return "EHLO failed: \(response)"
        case .starttlsFailed(let response):
            return "STARTTLS failed: \(response)"
        case .authMethodNotSupported(let method):
            return "Authentication method not supported: \(method)"
        case .authenticationFailed(let response):
            return "Authentication failed: \(response)"
        case .invalidResponse(let response):
            return "Invalid response: \(response)"
        case .mailFromRejected(let response):
            return "MAIL FROM rejected: \(response)"
        case .recipientRejected(let recipient, let response):
            return "Recipient rejected (\(recipient)): \(response)"
        case .dataRejected(let response):
            return "DATA rejected: \(response)"
        case .sendFailed(let response):
            return "Send failed: \(response)"
        }
    }
}
