import Foundation
import Security

/// Actor-based manager for secure credential storage in macOS Keychain.
///
/// Provides thread-safe operations for storing, retrieving, and deleting
/// credentials such as passwords and OAuth tokens.
actor KeychainManager {
    /// Shared singleton instance.
    static let shared = KeychainManager()

    private init() {}

    // MARK: - Password Operations

    /// Saves a password to the Keychain for a given account.
    /// - Parameters:
    ///   - password: The password to store.
    ///   - account: The account identifier (typically email address).
    /// - Throws: `KeychainError` if the operation fails.
    func save(password: String, forAccount account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Retrieves a password from the Keychain for a given account.
    /// - Parameter account: The account identifier.
    /// - Returns: The stored password, or nil if not found.
    /// - Throws: `KeychainError` if the operation fails (except for not found).
    func password(forAccount account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                throw KeychainError.decodingError
            }
            return password
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes credentials for a given account.
    /// - Parameter account: The account identifier.
    /// - Throws: `KeychainError` if the operation fails.
    func deleteCredentials(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - OAuth Token Operations

    /// Saves OAuth credentials to the Keychain.
    /// - Parameters:
    ///   - credentials: The OAuth credentials to store.
    ///   - account: The account identifier.
    /// - Throws: `KeychainError` if the operation fails.
    func save(oauthCredentials credentials: OAuthCredentials, forAccount account: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(AppConstants.keychainService).oauth",
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Retrieves OAuth credentials from the Keychain.
    /// - Parameter account: The account identifier.
    /// - Returns: The stored OAuth credentials, or nil if not found.
    /// - Throws: `KeychainError` if the operation fails.
    func oauthCredentials(forAccount account: String) throws -> OAuthCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(AppConstants.keychainService).oauth",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.decodingError
            }
            let decoder = JSONDecoder()
            return try decoder.decode(OAuthCredentials.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes OAuth credentials for a given account.
    /// - Parameter account: The account identifier.
    /// - Throws: `KeychainError` if the operation fails.
    func deleteOAuthCredentials(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(AppConstants.keychainService).oauth",
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes all credentials (password and OAuth) for a given account.
    /// - Parameter account: The account identifier.
    func deleteAllCredentials(forAccount account: String) async throws {
        try deleteCredentials(forAccount: account)
        try deleteOAuthCredentials(forAccount: account)
    }
}

// MARK: - Error Types

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, LocalizedError {
    case encodingError
    case decodingError
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "Failed to encode data for Keychain storage"
        case .decodingError:
            return "Failed to decode data from Keychain"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}
