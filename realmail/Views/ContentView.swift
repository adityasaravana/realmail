import SwiftUI
import SwiftData

/// Main content view with three-column navigation layout.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.email) private var accounts: [Account]

    @State private var selectedFolder: Folder?
    @State private var selectedMessage: Message?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                accounts: accounts,
                selectedFolder: $selectedFolder
            )
            .navigationSplitViewColumnWidth(min: AppConstants.UI.sidebarMinWidth, ideal: 250)
        } content: {
            if let folder = selectedFolder {
                MessageListView(
                    folder: folder,
                    selectedMessage: $selectedMessage
                )
                .navigationSplitViewColumnWidth(min: AppConstants.UI.messageListMinWidth, ideal: 350)
            } else {
                ContentUnavailableView(
                    "Select a Folder",
                    systemImage: "folder",
                    description: Text("Choose a folder from the sidebar to view messages.")
                )
            }
        } detail: {
            if let message = selectedMessage {
                MessageDetailView(message: message)
                    .navigationSplitViewColumnWidth(min: AppConstants.UI.detailMinWidth, ideal: AppConstants.UI.detailMinWidth)
            } else {
                ContentUnavailableView(
                    "No Message Selected",
                    systemImage: "envelope",
                    description: Text("Select a message to read it.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButtons
            }
        }
        .overlay {
            if accounts.isEmpty {
                EmptyAccountsView()
            }
        }
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            // TODO: Open compose window
        } label: {
            Label("Compose", systemImage: "square.and.pencil")
        }
        .help("New Message (⌘N)")

        Button {
            // TODO: Get new mail
        } label: {
            Label("Get Mail", systemImage: "arrow.clockwise")
        }
        .help("Get New Mail (⌘⇧K)")

        Spacer()

        if selectedMessage != nil {
            Button {
                // TODO: Reply
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            .help("Reply (⌘R)")

            Button {
                // TODO: Reply All
            } label: {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }
            .help("Reply All (⌘⇧R)")

            Button {
                // TODO: Forward
            } label: {
                Label("Forward", systemImage: "arrowshape.turn.up.right")
            }
            .help("Forward (⌘⇧F)")

            Divider()

            Button {
                // TODO: Move to trash
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help("Move to Trash (⌘⌫)")
        }
    }
}

/// View shown when no accounts are configured.
struct EmptyAccountsView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Welcome to RealMail")
                .font(.title)
                .fontWeight(.semibold)

            Text("Add an email account to get started.")
                .foregroundStyle(.secondary)

            Button("Add Account") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, Folder.self, Message.self], inMemory: true)
}
