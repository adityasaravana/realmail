import SwiftUI
import SwiftData

/// List view displaying messages in a folder.
struct MessageListView: View {
    let folder: Folder
    @Binding var selectedMessage: Message?

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var sortOrder = MessageSortOrder.dateDescending

    private var filteredMessages: [Message] {
        var messages = folder.messages

        // Apply search filter
        if !searchText.isEmpty {
            messages = messages.filter { message in
                message.subject.localizedCaseInsensitiveContains(searchText) ||
                message.fromAddress.localizedCaseInsensitiveContains(searchText) ||
                message.fromName?.localizedCaseInsensitiveContains(searchText) == true ||
                message.snippet?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Apply sort
        switch sortOrder {
        case .dateDescending:
            messages.sort { $0.date > $1.date }
        case .dateAscending:
            messages.sort { $0.date < $1.date }
        case .senderAscending:
            messages.sort { $0.fromAddress < $1.fromAddress }
        case .subjectAscending:
            messages.sort { $0.subject < $1.subject }
        }

        return messages
    }

    var body: some View {
        List(filteredMessages, selection: $selectedMessage) { message in
            MessageRow(message: message)
                .tag(message)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteMessage(message)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        archiveMessage(message)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.purple)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        toggleRead(message)
                    } label: {
                        Label(
                            message.isRead ? "Mark Unread" : "Mark Read",
                            systemImage: message.isRead ? "envelope.badge" : "envelope.open"
                        )
                    }
                    .tint(.blue)

                    Button {
                        toggleFlag(message)
                    } label: {
                        Label(
                            message.isFlagged ? "Unflag" : "Flag",
                            systemImage: message.isFlagged ? "flag.slash" : "flag"
                        )
                    }
                    .tint(.orange)
                }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Messages")
        .navigationTitle(folder.name)
        .navigationSubtitle("\(filteredMessages.count) messages")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(MessageSortOrder.allCases) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .overlay {
            if folder.messages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "tray",
                    description: Text("This folder is empty.")
                )
            } else if filteredMessages.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    // MARK: - Actions

    private func deleteMessage(_ message: Message) {
        // Move to trash or delete permanently if already in trash
        if folder.folderType == .trash {
            modelContext.delete(message)
        } else {
            // TODO: Move to trash folder
        }
    }

    private func archiveMessage(_ message: Message) {
        // TODO: Move to archive folder
    }

    private func toggleRead(_ message: Message) {
        message.markAsRead(!message.isRead)
        // TODO: Sync with IMAP
    }

    private func toggleFlag(_ message: Message) {
        message.setFlagged(!message.isFlagged)
        // TODO: Sync with IMAP
    }
}

/// Row displaying a single message in the list.
struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Unread indicator
            Circle()
                .fill(message.isRead ? .clear : .blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                // Sender and date
                HStack {
                    Text(message.formattedSender)
                        .font(.headline)
                        .fontWeight(message.isRead ? .regular : .semibold)
                        .lineLimit(1)

                    Spacer()

                    Text(message.date.mailListFormat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Subject
                HStack {
                    Text(message.subject)
                        .font(.subheadline)
                        .fontWeight(message.isRead ? .regular : .medium)
                        .lineLimit(1)

                    if message.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Preview
                if let snippet = message.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Flags
            VStack(spacing: 4) {
                if message.isFlagged {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if message.isAnswered {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Sort Order

enum MessageSortOrder: String, CaseIterable, Identifiable {
    case dateDescending
    case dateAscending
    case senderAscending
    case subjectAscending

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .senderAscending: return "Sender (A-Z)"
        case .subjectAscending: return "Subject (A-Z)"
        }
    }
}

// MARK: - Previews

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Folder.self, Message.self, configurations: config)

    let folder = Folder(name: "Inbox", path: "INBOX", folderType: .inbox, unreadCount: 2)

    let message1 = Message(
        uid: 1,
        subject: "Welcome to RealMail!",
        fromAddress: "hello@realmail.app",
        fromName: "RealMail Team",
        toAddresses: ["user@example.com"],
        date: Date(),
        bodyText: "Thanks for trying RealMail...",
        snippet: "Thanks for trying RealMail, your new email client.",
        isRead: false,
        hasAttachments: true,
        folder: folder
    )

    let message2 = Message(
        uid: 2,
        subject: "Meeting Tomorrow",
        fromAddress: "colleague@work.com",
        fromName: "John Smith",
        toAddresses: ["user@example.com"],
        date: Date().addingTimeInterval(-3600),
        bodyText: "Don't forget our meeting...",
        snippet: "Don't forget our meeting at 2pm tomorrow.",
        isRead: true,
        isFlagged: true,
        folder: folder
    )

    folder.messages = [message1, message2]

    container.mainContext.insert(folder)

    return NavigationStack {
        MessageListView(folder: folder, selectedMessage: .constant(nil))
    }
    .modelContainer(container)
}
