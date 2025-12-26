import Foundation
@testable import RealMail

/// Mock IMAP client for testing purposes.
actor MockIMAPClient {

    // MARK: - Configuration

    /// Simulated responses for different operations.
    var connectShouldSucceed = true
    var authenticateShouldSucceed = true
    var listMailboxesResult: [IMAPMailbox] = []
    var fetchHeadersResult: [IMAPMessageHeader] = []
    var fetchBodyResult: (text: String?, html: String?) = (nil, nil)

    /// Errors to throw for specific operations.
    var connectError: Error?
    var authenticateError: Error?
    var fetchError: Error?

    /// Track method calls for verification.
    private(set) var connectCallCount = 0
    private(set) var authenticateCallCount = 0
    private(set) var listMailboxesCallCount = 0
    private(set) var selectMailboxCallCount = 0
    private(set) var fetchHeadersCallCount = 0
    private(set) var idleCallCount = 0
    private(set) var disconnectCallCount = 0

    private(set) var lastSelectedMailbox: String?
    private(set) var lastFetchedUids: ClosedRange<UInt32>?

    // MARK: - Mock Methods

    func connect() async throws {
        connectCallCount += 1

        if let error = connectError {
            throw error
        }

        if !connectShouldSucceed {
            throw MockError.connectionFailed
        }
    }

    func authenticateOAuth(email: String, accessToken: String) async throws {
        authenticateCallCount += 1

        if let error = authenticateError {
            throw error
        }

        if !authenticateShouldSucceed {
            throw MockError.authenticationFailed
        }
    }

    func listMailboxes() async throws -> [IMAPMailbox] {
        listMailboxesCallCount += 1
        return listMailboxesResult
    }

    func selectMailbox(_ name: String) async throws {
        selectMailboxCallCount += 1
        lastSelectedMailbox = name
    }

    func fetchHeaders(uids: ClosedRange<UInt32>) async throws -> [IMAPMessageHeader] {
        fetchHeadersCallCount += 1
        lastFetchedUids = uids

        if let error = fetchError {
            throw error
        }

        return fetchHeadersResult
    }

    func fetchBody(uid: UInt32) async throws -> (text: String?, html: String?) {
        if let error = fetchError {
            throw error
        }
        return fetchBodyResult
    }

    func idle(handler: @escaping (IDLEEvent) -> Void) async throws {
        idleCallCount += 1
        // Simulated idle - does nothing in tests
    }

    func disconnect() async {
        disconnectCallCount += 1
    }

    // MARK: - Reset

    func reset() {
        connectCallCount = 0
        authenticateCallCount = 0
        listMailboxesCallCount = 0
        selectMailboxCallCount = 0
        fetchHeadersCallCount = 0
        idleCallCount = 0
        disconnectCallCount = 0
        lastSelectedMailbox = nil
        lastFetchedUids = nil

        connectShouldSucceed = true
        authenticateShouldSucceed = true
        connectError = nil
        authenticateError = nil
        fetchError = nil
    }
}

// MARK: - Supporting Types

/// Mock mailbox for testing.
struct IMAPMailbox: Sendable {
    let name: String
    let path: String
    let attributes: [String]
    let delimiter: Character

    init(name: String, path: String, attributes: [String] = [], delimiter: Character = "/") {
        self.name = name
        self.path = path
        self.attributes = attributes
        self.delimiter = delimiter
    }
}

/// Mock message header for testing.
struct IMAPMessageHeader: Sendable {
    let uid: UInt32
    let subject: String
    let fromAddress: String
    let fromName: String?
    let toAddresses: [String]
    let date: Date
    let messageId: String?
    let inReplyTo: String?
    let flags: Set<String>
}

/// Mock IDLE events.
enum IDLEEvent: Sendable {
    case newMessage(mailbox: String, count: Int)
    case flagsChanged(uid: UInt32)
    case expunge(uid: UInt32)
}

/// Mock errors for testing.
enum MockError: Error, LocalizedError {
    case connectionFailed
    case authenticationFailed
    case networkError
    case timeout
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Connection failed"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError:
            return "Network error"
        case .timeout:
            return "Request timed out"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
