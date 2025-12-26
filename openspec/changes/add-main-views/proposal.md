# Proposal: Add Main Views

## Overview
Implement the core SwiftUI views for the email client including the three-column navigation layout, message list, message detail, and compose window.

## Motivation
A native macOS email client requires proper adherence to Human Interface Guidelines with a familiar three-column layout, keyboard navigation, and native controls.

## Scope

### In Scope
- Three-column NavigationSplitView layout
- Sidebar with accounts and folders
- Message list with preview
- Message detail view with HTML rendering
- Compose window as separate Window
- Account settings sheet
- Toolbar with common actions
- Keyboard shortcuts
- Search functionality

### Out of Scope
- Advanced search filters
- Message threading UI (future enhancement)
- Custom themes

## Technical Approach

### App Structure
```swift
@main
struct RealMailApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands { MailCommands() }

        Window("Compose", id: "compose") {
            ComposeView()
        }

        Settings {
            SettingsView()
        }
    }
}
```

### Three-Column Layout
```swift
struct ContentView: View {
    @State private var selectedAccount: Account?
    @State private var selectedFolder: Folder?
    @State private var selectedMessage: Message?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedFolder)
        } content: {
            MessageListView(
                folder: selectedFolder,
                selection: $selectedMessage
            )
        } detail: {
            MessageDetailView(message: selectedMessage)
        }
    }
}
```

### View Components

#### SidebarView
- Account list with disclosure groups
- Folder tree with unread badges
- Drag-drop for message filing
- Context menu for folder actions

#### MessageListView
- Virtualized List for performance
- Swipe actions (delete, flag, archive)
- Sort options (date, sender, subject)
- Quick preview on selection

#### MessageDetailView
- Header display (from, to, date, subject)
- WebView for HTML content
- Attachment list with Quick Look
- Reply/Forward/Delete actions

#### ComposeView
- Recipient fields with autocomplete
- Rich text editor (optional HTML)
- Attachment drag-drop
- Draft auto-save

### ViewModels
Using `@Observable` for reactive updates:
```swift
@Observable
class MailboxViewModel {
    var folders: [Folder] = []
    var selectedFolder: Folder?
    var messages: [Message] = []
    var isLoading = false
    var error: Error?

    func loadFolders(for account: Account) async
    func loadMessages(for folder: Folder) async
    func refresh() async
}
```

## Scenarios

### Scenario: Launch App with Accounts
- Given the user has configured accounts
- When the app launches
- Then the sidebar shows all accounts with folders
- And INBOX is selected by default
- And messages are displayed in the list

### Scenario: Navigate Between Folders
- Given the user clicks a folder in sidebar
- When the folder is selected
- Then the message list updates to show folder contents
- And any selected message is deselected
- And list scrolls to top

### Scenario: View Message Detail
- Given the message list has messages
- When the user selects a message
- Then the detail pane shows the full message
- And the message is marked as read
- And attachments are listed

### Scenario: Compose New Message
- Given the user clicks Compose or presses ⌘N
- When the compose action is triggered
- Then a new compose window opens
- And the From field shows the active account
- And focus is on the To field

### Scenario: Reply to Message
- Given a message is selected
- When the user clicks Reply or presses ⌘R
- Then compose window opens with quoted content
- And To field has original sender
- And subject has "Re:" prefix

### Scenario: Delete Message
- Given a message is selected
- When the user presses Delete or swipes
- Then the message is moved to Trash
- And the next message is selected
- And the list updates

### Scenario: Search Messages
- Given the search field is active
- When the user types a query
- Then messages are filtered in real-time
- And matching results are highlighted
- And clearing search restores full list

### Scenario: Keyboard Navigation
- Given the message list is focused
- When the user presses ↑/↓ arrows
- Then the selection moves through messages
- And Enter opens the message
- And Space toggles read status

## Task Breakdown

1. Create `ContentView` with NavigationSplitView
2. Implement `SidebarView` with account/folder tree
3. Create `FolderRowView` with unread badge
4. Implement `MessageListView` with virtualized List
5. Create `MessageRowView` with preview layout
6. Implement swipe actions for messages
7. Create `MessageDetailView` with header
8. Integrate WKWebView for HTML content
9. Add attachment list with Quick Look preview
10. Create `ComposeView` as separate window
11. Implement recipient field with autocomplete
12. Add rich text editing support
13. Implement attachment drag-drop
14. Create `MailboxViewModel` observable
15. Create `ComposeViewModel` observable
16. Add keyboard shortcuts via Commands
17. Implement search with @Query filtering
18. Create `SettingsView` for account management
19. Add toolbar with action buttons
20. Style views according to HIG
