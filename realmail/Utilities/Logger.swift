import Foundation
import os.log

/// Centralized logging utility using OSLog.
///
/// Provides categorized logging with appropriate privacy levels
/// for different types of information.
enum Log {
    /// Logger for general application events.
    static let app = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "app"
    )

    /// Logger for authentication and account operations.
    static let auth = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "auth"
    )

    /// Logger for IMAP synchronization operations.
    static let imap = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "imap"
    )

    /// Logger for SMTP sending operations.
    static let smtp = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "smtp"
    )

    /// Logger for SwiftData and persistence operations.
    static let data = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "data"
    )

    /// Logger for network operations.
    static let network = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "network"
    )

    /// Logger for UI and view-related events.
    static let ui = Logger(
        subsystem: AppConstants.appIdentifier,
        category: "ui"
    )
}

// MARK: - Logger Static Accessors

extension Logger {
    /// Logger for general application events.
    static let app = Log.app

    /// Logger for authentication and account operations.
    static let auth = Log.auth

    /// Logger for IMAP synchronization operations.
    static let imap = Log.imap

    /// Logger for SMTP sending operations.
    static let smtp = Log.smtp

    /// Logger for SwiftData and persistence operations.
    static let data = Log.data

    /// Logger for network operations.
    static let network = Log.network

    /// Logger for UI and view-related events.
    static let ui = Log.ui
}

// MARK: - Logger Extensions

extension Logger {
    /// Logs an error with additional context.
    /// - Parameters:
    ///   - error: The error to log.
    ///   - message: Additional context message.
    func error(_ error: Error, message: String? = nil) {
        if let message = message {
            self.error("\(message): \(error.localizedDescription)")
        } else {
            self.error("\(error.localizedDescription)")
        }
    }

    /// Logs the entry to a function or method.
    /// - Parameters:
    ///   - function: The function name (default: caller's function name).
    ///   - file: The file name (default: caller's file).
    func enter(function: String = #function, file: String = #file) {
        let filename = (file as NSString).lastPathComponent
        self.trace("→ \(filename):\(function)")
    }

    /// Logs the exit from a function or method.
    /// - Parameter function: The function name (default: caller's function name).
    func exit(function: String = #function) {
        self.trace("← \(function)")
    }

    /// Logs a network request.
    /// - Parameters:
    ///   - method: HTTP method or protocol command.
    ///   - endpoint: The target endpoint or server.
    func request(_ method: String, to endpoint: String) {
        self.info("→ \(method) \(endpoint, privacy: .public)")
    }

    /// Logs a network response.
    /// - Parameters:
    ///   - status: Response status code or status string.
    ///   - endpoint: The responding endpoint.
    func response(_ status: String, from endpoint: String) {
        self.info("← \(status) \(endpoint, privacy: .public)")
    }
}
