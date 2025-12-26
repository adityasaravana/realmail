import Foundation

/// OAuth2 credentials for email authentication.
struct OAuthCredentials: Codable, Sendable {
    /// OAuth2 access token for API authentication.
    let accessToken: String

    /// Refresh token for obtaining new access tokens.
    let refreshToken: String

    /// Expiration date of the access token.
    let expiresAt: Date

    /// Token type (typically "Bearer").
    let tokenType: String

    /// OAuth scopes granted.
    let scopes: [String]

    /// Email address associated with these credentials.
    let email: String

    /// Creates new OAuth credentials.
    init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        tokenType: String = "Bearer",
        scopes: [String] = [],
        email: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
        self.scopes = scopes
        self.email = email
    }

    /// Creates credentials from an OAuth token response.
    init(from response: OAuthTokenResponse, email: String, scopes: [String]) {
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken ?? ""
        self.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        self.tokenType = response.tokenType ?? "Bearer"
        self.scopes = scopes
        self.email = email
    }

    /// Whether the access token has expired or is about to expire.
    var isExpired: Bool {
        // Consider expired if less than 5 minutes remaining
        Date().addingTimeInterval(300) >= expiresAt
    }

    /// Whether these credentials have a refresh token.
    var canRefresh: Bool {
        !refreshToken.isEmpty
    }

    /// Authorization header value for API requests.
    var authorizationHeader: String {
        "\(tokenType) \(accessToken)"
    }

    /// XOAUTH2 authentication string for IMAP/SMTP.
    /// Format: base64("user=" + email + "^Aauth=Bearer " + token + "^A^A")
    var xoauth2String: String {
        let authString = "user=\(email)\u{01}auth=Bearer \(accessToken)\u{01}\u{01}"
        return Data(authString.utf8).base64EncodedString()
    }
}

// MARK: - OAuth Token Response

/// Standard OAuth2 token endpoint response.
struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }

    /// Parses scopes from the scope string.
    var scopes: [String] {
        scope?.components(separatedBy: " ") ?? []
    }
}

// MARK: - OAuth Configuration

/// OAuth2 configuration for an email provider.
struct OAuthConfig: Sendable {
    /// Client ID for the OAuth application.
    let clientId: String

    /// Client secret (if applicable, not used for PKCE).
    let clientSecret: String?

    /// Authorization endpoint URL.
    let authorizationURL: URL

    /// Token endpoint URL.
    let tokenURL: URL

    /// Redirect URI for callback.
    let redirectURI: String

    /// OAuth scopes to request.
    let scopes: [String]

    /// Whether to use PKCE (recommended for native apps).
    let usePKCE: Bool

    /// Gmail OAuth configuration.
    static var gmail: OAuthConfig {
        OAuthConfig(
            clientId: OAuthSecrets.gmailClientId,
            clientSecret: nil,
            authorizationURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            redirectURI: OAuthSecrets.gmailRedirectURI,
            scopes: [
                "https://mail.google.com/",
                "email",
                "profile"
            ],
            usePKCE: true
        )
    }

    /// Outlook/Microsoft OAuth configuration.
    static var outlook: OAuthConfig {
        OAuthConfig(
            clientId: OAuthSecrets.outlookClientId,
            clientSecret: nil,
            authorizationURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
            redirectURI: OAuthSecrets.outlookRedirectURI,
            scopes: [
                "https://outlook.office.com/IMAP.AccessAsUser.All",
                "https://outlook.office.com/SMTP.Send",
                "offline_access",
                "openid",
                "profile",
                "email"
            ],
            usePKCE: true
        )
    }
}

// MARK: - OAuth Secrets (Replace with actual values)

/// OAuth client credentials - should be stored securely in production.
enum OAuthSecrets {
    // Gmail
    static let gmailClientId = "YOUR_GMAIL_CLIENT_ID.apps.googleusercontent.com"
    static let gmailRedirectURI = "com.realmail.app:/oauth2callback"

    // Outlook
    static let outlookClientId = "YOUR_OUTLOOK_CLIENT_ID"
    static let outlookRedirectURI = "msauth.com.realmail.app://auth"
}
