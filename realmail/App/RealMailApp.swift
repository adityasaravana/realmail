import SwiftUI
import SwiftData

/// Main entry point for the RealMail macOS application.
@main
struct RealMailApp: App {
    /// SwiftData model container configured with all persistent models.
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Account.self,
                Folder.self,
                Message.self,
                Attachment.self,
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // Main application window
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(modelContainer)
        .commands {
            MailCommands()
        }

        // Compose window opened via openWindow
        Window("Compose", id: "compose") {
            ComposeView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 700, height: 600)

        // Settings window
        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}

/// Custom menu commands for mail operations.
struct MailCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // File menu additions
        CommandGroup(after: .newItem) {
            Button("New Message") {
                openWindow(id: "compose")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Message menu
        CommandMenu("Message") {
            Button("Reply") {
                NotificationCenter.default.post(name: .replyToMessage, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Reply All") {
                NotificationCenter.default.post(name: .replyAllToMessage, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Forward") {
                NotificationCenter.default.post(name: .forwardMessage, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button("Mark as Read") {
                NotificationCenter.default.post(name: .markAsRead, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Button("Flag") {
                NotificationCenter.default.post(name: .flagMessage, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Divider()

            Button("Move to Trash") {
                NotificationCenter.default.post(name: .moveToTrash, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }

        // Mailbox menu
        CommandMenu("Mailbox") {
            Button("Get New Mail") {
                NotificationCenter.default.post(name: .syncMailbox, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("Synchronize All Accounts") {
                NotificationCenter.default.post(name: .syncAllAccounts, object: nil)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let replyToMessage = Notification.Name("replyToMessage")
    static let replyAllToMessage = Notification.Name("replyAllToMessage")
    static let forwardMessage = Notification.Name("forwardMessage")
    static let markAsRead = Notification.Name("markAsRead")
    static let flagMessage = Notification.Name("flagMessage")
    static let moveToTrash = Notification.Name("moveToTrash")
    static let syncMailbox = Notification.Name("syncMailbox")
    static let syncAllAccounts = Notification.Name("syncAllAccounts")
}
