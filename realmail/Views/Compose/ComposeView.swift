import SwiftUI
import SwiftData

/// Compose view for creating and sending email messages.
struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.email) private var accounts: [Account]

    @State private var selectedAccount: Account?
    @State private var toRecipients: String = ""
    @State private var ccRecipients: String = ""
    @State private var bccRecipients: String = ""
    @State private var subject: String = ""
    @State private var body: String = ""
    @State private var showCcBcc = false
    @State private var attachments: [URL] = []
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            // Header fields
            VStack(spacing: 8) {
                // From picker
                HStack {
                    Text("From:")
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    Picker("", selection: $selectedAccount) {
                        ForEach(accounts) { account in
                            Text(account.email).tag(account as Account?)
                        }
                    }
                    .labelsHidden()
                }

                // To field
                HStack {
                    Text("To:")
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    TextField("Recipients", text: $toRecipients)
                        .textFieldStyle(.plain)

                    Button {
                        showCcBcc.toggle()
                    } label: {
                        Image(systemName: showCcBcc ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.plain)
                    .help("Show Cc/Bcc fields")
                }

                if showCcBcc {
                    // Cc field
                    HStack {
                        Text("Cc:")
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)

                        TextField("Carbon copy", text: $ccRecipients)
                            .textFieldStyle(.plain)
                    }

                    // Bcc field
                    HStack {
                        Text("Bcc:")
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)

                        TextField("Blind carbon copy", text: $bccRecipients)
                            .textFieldStyle(.plain)
                    }
                }

                // Subject field
                HStack {
                    Text("Subject:")
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    TextField("Subject", text: $subject)
                        .textFieldStyle(.plain)
                }
            }
            .padding()

            Divider()

            // Body editor
            TextEditor(text: $body)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding()

            // Attachments bar
            if !attachments.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(attachments, id: \.self) { url in
                            AttachmentBadge(url: url) {
                                attachments.removeAll { $0 == url }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 44)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    sendMessage()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .disabled(toRecipients.isEmpty || isSending)
                .help("Send Message (⌘↩)")
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    attachFile()
                } label: {
                    Label("Attach", systemImage: "paperclip")
                }
                .help("Attach File")

                Button {
                    saveDraft()
                } label: {
                    Label("Save Draft", systemImage: "square.and.arrow.down")
                }
                .help("Save as Draft")
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedAccount = accounts.first
        }
    }

    private func sendMessage() {
        isSending = true
        // TODO: Implement message sending
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            attachments.append(contentsOf: panel.urls)
        }
    }

    private func saveDraft() {
        // TODO: Implement draft saving
        dismiss()
    }
}

/// Badge displaying an attachment with remove button.
struct AttachmentBadge: View {
    let url: URL
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc")
            Text(url.lastPathComponent)
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(4)
    }
}

#Preview {
    ComposeView()
        .frame(width: 600, height: 500)
        .modelContainer(for: Account.self, inMemory: true)
}
