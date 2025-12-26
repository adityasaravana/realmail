import Foundation
import AuthenticationServices
import CryptoKit
import os.log

/// Service for managing email account authentication.
actor AuthService {
    /// Shared singleton instance.
    static let shared = AuthService()

    private let keychainManager = KeychainManager.shared
    private let logger = Logger.auth

    private init() {}

    // MARK: - OAuth Flow

    /// Initiates OAuth authentication for a provider.
    /// - Parameters:
    ///   - provider: The email provider (gmail or outlook).
    ///   - presentingWindow: The window to present the auth session.
    /// - Returns: OAuth credentials on success.
    func authenticateWithOAuth(
        provider: AccountProvider,
        presentingWindow: NSWindow? = nil
    ) async throws -> OAuthCredentials {
        guard provider.supportsOAuth else {
            throw AuthError.oauthNotSupported(provider)
        }

        let config = oauthConfig(for: provider)

        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Build authorization URL
        let authURL = try buildAuthorizationURL(config: config, codeChallenge: codeChallenge)

        // Perform OAuth flow
        let callbackURL = try await performWebAuthentication(
            authURL: authURL,
            callbackScheme: URL(string: config.redirectURI)!.scheme!,
            presentingWindow: presentingWindow
        )

        // Extract authorization code from callback
        let authCode = try extractAuthorizationCode(from: callbackURL)

        // Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            config: config,
            authCode: authCode,
            codeVerifier: codeVerifier
        )

        // Get user email from ID token or userinfo endpoint
        let email = try await fetchUserEmail(config: config, accessToken: tokenResponse.accessToken)

        // Create and store credentials
        let credentials = OAuthCredentials(
            from: tokenResponse,
            email: email,
            scopes: config.scopes
        )

        try await keychainManager.save(oauthCredentials: credentials, forAccount: email)
        logger.info("OAuth authentication successful for \(email)")

        return credentials
    }

    /// Refreshes OAuth tokens for an account.
    func refreshTokens(for email: String) async throws -> OAuthCredentials {
        guard let credentials = try await keychainManager.oauthCredentials(forAccount: email) else {
            throw AuthError.credentialsNotFound(email)
        }

        guard credentials.canRefresh else {
            throw AuthError.noRefreshToken
        }

        // Determine provider from email
        let provider = AccountProvider.detect(from: email)
        let config = oauthConfig(for: provider)

        // Refresh tokens
        let tokenResponse = try await refreshTokens(
            config: config,
            refreshToken: credentials.refreshToken
        )

        // Update credentials
        let newCredentials = OAuthCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? credentials.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            tokenType: tokenResponse.tokenType ?? "Bearer",
            scopes: credentials.scopes,
            email: email
        )

        try await keychainManager.save(oauthCredentials: newCredentials, forAccount: email)
        logger.info("Token refresh successful for \(email)")

        return newCredentials
    }

    /// Gets valid OAuth credentials, refreshing if needed.
    func getValidCredentials(for email: String) async throws -> OAuthCredentials {
        guard var credentials = try await keychainManager.oauthCredentials(forAccount: email) else {
            throw AuthError.credentialsNotFound(email)
        }

        if credentials.isExpired {
            logger.debug("Access token expired for \(email), refreshing...")
            credentials = try await refreshTokens(for: email)
        }

        return credentials
    }

    // MARK: - Password Authentication

    /// Stores password credentials for an account.
    func storePassword(_ password: String, for email: String) async throws {
        try await keychainManager.save(password: password, forAccount: email)
        logger.info("Password stored for \(email)")
    }

    /// Retrieves password for an account.
    func getPassword(for email: String) async throws -> String {
        guard let password = try await keychainManager.password(forAccount: email) else {
            throw AuthError.credentialsNotFound(email)
        }
        return password
    }

    // MARK: - Credential Management

    /// Validates stored credentials by testing connection.
    func validateCredentials(for account: Account) async throws -> Bool {
        switch account.authType {
        case .oauth2:
            let credentials = try await getValidCredentials(for: account.email)
            return !credentials.isExpired
        case .password:
            let password = try await getPassword(for: account.email)
            return !password.isEmpty
            // TODO: Actually test IMAP connection
        }
    }

    /// Revokes OAuth tokens for an account.
    func revokeOAuthTokens(for email: String) async throws {
        guard let credentials = try await keychainManager.oauthCredentials(forAccount: email) else {
            return
        }

        let provider = AccountProvider.detect(from: email)

        // Revoke with provider
        switch provider {
        case .gmail:
            try await revokeGoogleToken(credentials.accessToken)
        case .outlook:
            // Microsoft doesn't have a simple revocation endpoint for native apps
            break
        default:
            break
        }

        // Delete from keychain
        try await keychainManager.deleteCredentials(forAccount: email)
        logger.info("OAuth tokens revoked for \(email)")
    }

    /// Deletes all credentials for an account.
    func deleteCredentials(for email: String) async throws {
        try await keychainManager.deleteCredentials(forAccount: email)
        logger.info("Credentials deleted for \(email)")
    }

    // MARK: - Private Helpers

    private func oauthConfig(for provider: AccountProvider) -> OAuthConfig {
        switch provider {
        case .gmail:
            return .gmail
        case .outlook:
            return .outlook
        default:
            fatalError("OAuth not supported for \(provider)")
        }
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func buildAuthorizationURL(config: OAuthConfig, codeChallenge: String) throws -> URL {
        var components = URLComponents(url: config.authorizationURL, resolvingAgainstBaseURL: false)!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        if config.usePKCE {
            components.queryItems?.append(contentsOf: [
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
            ])
        }

        guard let url = components.url else {
            throw AuthError.invalidURL
        }

        return url
    }

    private func performWebAuthentication(
        authURL: URL,
        callbackScheme: String,
        presentingWindow: NSWindow?
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: AuthError.webAuthFailed(error))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthError.noCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = WebAuthPresenter.shared
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: AuthError.sessionStartFailed)
            }
        }
    }

    private func extractAuthorizationCode(from url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            if let error = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "error" })?.value {
                throw AuthError.authorizationDenied(error)
            }
            throw AuthError.noAuthorizationCode
        }
        return code
    }

    private func exchangeCodeForTokens(
        config: OAuthConfig,
        authCode: String,
        codeVerifier: String
    ) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = [
            "client_id": config.clientId,
            "code": authCode,
            "redirect_uri": config.redirectURI,
            "grant_type": "authorization_code",
        ]

        if config.usePKCE {
            body["code_verifier"] = codeVerifier
        }

        if let clientSecret = config.clientSecret {
            body["client_secret"] = clientSecret
        }

        request.httpBody = body.map { "\($0)=\($1.urlEncoded)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(httpResponse.statusCode, errorBody)
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func refreshTokens(config: OAuthConfig, refreshToken: String) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = [
            "client_id": config.clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]

        if let clientSecret = config.clientSecret {
            body["client_secret"] = clientSecret
        }

        request.httpBody = body.map { "\($0)=\($1.urlEncoded)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenRefreshFailed(httpResponse.statusCode, errorBody)
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func fetchUserEmail(config: OAuthConfig, accessToken: String) async throws -> String {
        // For Google, use userinfo endpoint
        let userinfoURL: URL
        if config.authorizationURL.host?.contains("google") == true {
            userinfoURL = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!
        } else {
            // Microsoft Graph
            userinfoURL = URL(string: "https://graph.microsoft.com/v1.0/me")!
        }

        var request = URLRequest(url: userinfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct UserInfo: Codable {
            let email: String?
            let mail: String? // Microsoft uses "mail"
            let userPrincipalName: String? // Fallback for Microsoft
        }

        let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)

        if let email = userInfo.email ?? userInfo.mail ?? userInfo.userPrincipalName {
            return email
        }

        throw AuthError.noEmailInToken
    }

    private func revokeGoogleToken(_ token: String) async throws {
        let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!
        var request = URLRequest(url: revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "token=\(token)".data(using: .utf8)

        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Web Auth Presenter

/// Provides the presentation anchor for ASWebAuthenticationSession.
final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    static let shared = WebAuthPresenter()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first!
    }
}

// MARK: - Auth Errors

/// Errors that can occur during authentication.
enum AuthError: LocalizedError {
    case oauthNotSupported(AccountProvider)
    case invalidURL
    case userCancelled
    case webAuthFailed(Error)
    case noCallbackURL
    case sessionStartFailed
    case authorizationDenied(String)
    case noAuthorizationCode
    case invalidResponse
    case tokenExchangeFailed(Int, String)
    case tokenRefreshFailed(Int, String)
    case noEmailInToken
    case credentialsNotFound(String)
    case noRefreshToken
    case keychainError(Error)

    var errorDescription: String? {
        switch self {
        case .oauthNotSupported(let provider):
            return "OAuth is not supported for \(provider.displayName)."
        case .invalidURL:
            return "Failed to build authentication URL."
        case .userCancelled:
            return "Authentication was cancelled."
        case .webAuthFailed(let error):
            return "Web authentication failed: \(error.localizedDescription)"
        case .noCallbackURL:
            return "No callback URL received."
        case .sessionStartFailed:
            return "Failed to start authentication session."
        case .authorizationDenied(let error):
            return "Authorization denied: \(error)"
        case .noAuthorizationCode:
            return "No authorization code received."
        case .invalidResponse:
            return "Invalid response from authentication server."
        case .tokenExchangeFailed(let code, let body):
            return "Token exchange failed (\(code)): \(body)"
        case .tokenRefreshFailed(let code, let body):
            return "Token refresh failed (\(code)): \(body)"
        case .noEmailInToken:
            return "Could not determine email from authentication response."
        case .credentialsNotFound(let email):
            return "No credentials found for \(email)."
        case .noRefreshToken:
            return "No refresh token available."
        case .keychainError(let error):
            return "Keychain error: \(error.localizedDescription)"
        }
    }
}

// MARK: - String URL Encoding

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
