import SwiftUI
import SwiftData

/// Sidebar view displaying accounts and their folder hierarchies.
struct SidebarView: View {
    let accounts: [Account]
    @Binding var selectedFolder: Folder?

    @State private var expandedAccounts: Set<UUID> = []
    @State private var searchText = ""

    var body: some View {
        List(selection: $selectedFolder) {
            ForEach(accounts) { account in
                AccountSection(
                    account: account,
                    selectedFolder: $selectedFolder,
                    isExpanded: Binding(
                        get: { expandedAccounts.contains(account.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedAccounts.insert(account.id)
                            } else {
                                expandedAccounts.remove(account.id)
                            }
                        }
                    )
                )
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search Folders")
        .navigationTitle("Mail")
        .onAppear {
            // Expand all accounts by default
            expandedAccounts = Set(accounts.map(\.id))

            // Select inbox of first account if nothing selected
            if selectedFolder == nil, let firstAccount = accounts.first,
               let inbox = firstAccount.folders.first(where: { $0.folderType == .inbox }) {
                selectedFolder = inbox
            }
        }
    }
}

/// Section for a single account with its folders.
struct AccountSection: View {
    let account: Account
    @Binding var selectedFolder: Folder?
    @Binding var isExpanded: Bool

    private var sortedFolders: [Folder] {
        account.folders
            .filter { $0.parent == nil } // Only top-level folders
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach(sortedFolders) { folder in
                FolderRow(folder: folder, selectedFolder: $selectedFolder)
            }
        } header: {
            HStack {
                Image(systemName: account.provider.iconName)
                    .foregroundStyle(account.provider.color)
                    .font(.caption)

                Text(account.displayName ?? account.email)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if !account.isEnabled {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .help("Account disabled")
                }
            }
            .contentShape(Rectangle())
        }
    }
}

/// Row for a single folder with optional children.
struct FolderRow: View {
    let folder: Folder
    @Binding var selectedFolder: Folder?

    @State private var isExpanded = true

    private var sortedChildren: [Folder] {
        folder.children.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        if folder.children.isEmpty {
            // Leaf folder
            folderLabel
                .tag(folder)
        } else {
            // Folder with children
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(sortedChildren) { child in
                    FolderRow(folder: child, selectedFolder: $selectedFolder)
                }
            } label: {
                folderLabel
            }
        }
    }

    private var folderLabel: some View {
        HStack {
            Image(systemName: folder.folderType.iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(folder.name)
                .lineLimit(1)

            Spacer()

            if folder.unreadCount > 0 {
                Text("\(folder.unreadCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        switch folder.folderType {
        case .inbox:
            return .blue
        case .sent:
            return .green
        case .drafts:
            return .orange
        case .trash:
            return .red
        case .spam:
            return .brown
        case .flagged:
            return .yellow
        case .archive:
            return .purple
        default:
            return .secondary
        }
    }

    private var badgeColor: Color {
        folder.folderType == .inbox ? .blue : .secondary
    }
}

// MARK: - Previews

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Folder.self, configurations: config)

    // Create sample data
    let account = Account(
        email: "user@gmail.com",
        displayName: "Gmail",
        provider: .gmail,
        imapHost: "imap.gmail.com",
        smtpHost: "smtp.gmail.com"
    )

    let inbox = Folder(name: "Inbox", path: "INBOX", folderType: .inbox, unreadCount: 5, account: account)
    let sent = Folder(name: "Sent", path: "[Gmail]/Sent Mail", folderType: .sent, account: account)
    let drafts = Folder(name: "Drafts", path: "[Gmail]/Drafts", folderType: .drafts, account: account)
    let trash = Folder(name: "Trash", path: "[Gmail]/Trash", folderType: .trash, account: account)

    account.folders = [inbox, sent, drafts, trash]

    container.mainContext.insert(account)

    return NavigationSplitView {
        SidebarView(accounts: [account], selectedFolder: .constant(inbox))
    } detail: {
        Text("Detail")
    }
    .modelContainer(container)
}
