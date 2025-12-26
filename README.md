# RealMail

A native macOS email client built with Swift, SwiftUI, and SwiftData.

## Features

- **Native macOS Experience** - Built with SwiftUI for a modern, responsive interface
- **Multiple Account Support** - Gmail, Outlook, iCloud, Yahoo, and custom IMAP/SMTP servers
- **OAuth2 Authentication** - Secure authentication for Gmail and Outlook with PKCE
- **Offline Support** - Messages queue locally and send automatically when online
- **Three-Column Layout** - Standard email client interface with sidebar, message list, and detail view
- **HTML Email Rendering** - Full HTML email support via WKWebView
- **Attachments** - Send and receive file attachments with preview
- **Threading** - Conversation threading via In-Reply-To and References headers
- **IDLE Push** - Real-time new message notifications via IMAP IDLE

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Architecture

```
RealMail/
├── App/
│   ├── RealMailApp.swift       # App entry point
│   └── AppConstants.swift      # Configuration
├── Models/                     # SwiftData models
│   ├── Account.swift
│   ├── Folder.swift
│   ├── Message.swift
│   ├── Attachment.swift
│   └── EmailAddress.swift
├── Views/
│   ├── ContentView.swift       # Main three-column layout
│   ├── Sidebar/
│   ├── MessageList/
│   ├── MessageDetail/
│   ├── Compose/
│   └── SettingsView.swift
├── ViewModels/
│   └── MailboxViewModel.swift
├── Services/
│   ├── Auth/                   # OAuth2 & password auth
│   ├── IMAP/                   # IMAP client & sync
│   └── SMTP/                   # SMTP client & send queue
└── Utilities/
    ├── KeychainManager.swift   # Secure credential storage
    ├── Logger.swift            # OSLog logging
    └── Extensions/
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Persistence | SwiftData |
| Networking | Network.framework |
| Authentication | ASWebAuthenticationSession |
| Credentials | macOS Keychain |
| HTML Rendering | WKWebView |
| Logging | OSLog |

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/realmail.git
cd realmail
```

### 2. Configure OAuth Credentials

Edit `RealMail/Services/Auth/OAuthCredentials.swift` and replace the placeholder values:

```swift
enum OAuthSecrets {
    // Gmail - Get from Google Cloud Console
    static let gmailClientId = "YOUR_GMAIL_CLIENT_ID.apps.googleusercontent.com"
    static let gmailRedirectURI = "com.realmail.app:/oauth2callback"

    // Outlook - Get from Azure Portal
    static let outlookClientId = "YOUR_OUTLOOK_CLIENT_ID"
    static let outlookRedirectURI = "msauth.com.realmail.app://auth"
}
```

### 3. Build and Run

Open in Xcode and run:

```bash
open RealMail.xcodeproj
```

Or build from command line:

```bash
xcodebuild -scheme RealMail -configuration Debug build
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Message |
| ⌘R | Reply |
| ⇧⌘R | Reply All |
| ⇧⌘F | Forward |
| ⌘⌫ | Move to Trash |
| ⇧⌘U | Mark as Read/Unread |
| ⇧⌘L | Flag/Unflag |
| ⇧⌘K | Get New Mail |

## Project Status

This project was built using [OpenSpec](openspec/README.md) for specification-driven development.

### Implemented

- [x] App infrastructure (entry point, settings, commands)
- [x] SwiftData models (Account, Folder, Message, Attachment)
- [x] OAuth2 authentication (Gmail, Outlook)
- [x] Password authentication (custom IMAP)
- [x] IMAP client with sync service
- [x] SMTP client with send queue
- [x] Three-column navigation UI
- [x] Message list with swipe actions
- [x] HTML email rendering
- [x] Compose window with attachments

### Planned

- [ ] Contact autocomplete
- [ ] Full-text search
- [ ] Notification integration
- [ ] Unified inbox view
- [ ] Rules and filters
- [ ] Signature management

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting a pull request.
