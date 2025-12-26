import SwiftUI
import SwiftData
import WebKit

/// Detail view displaying full message content.
struct MessageDetailView: View {
    @Bindable var message: Message

    @Environment(\.openWindow) private var openWindow
    @State private var loadExternalImages = false
    @State private var showingAttachments = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                MessageHeaderView(message: message)

                Divider()
                    .padding(.vertical, 8)

                // Attachments
                if message.hasAttachments && !message.attachments.isEmpty {
                    AttachmentBarView(
                        attachments: message.attachments,
                        isExpanded: $showingAttachments
                    )

                    Divider()
                        .padding(.vertical, 8)
                }

                // Body
                MessageBodyView(
                    message: message,
                    loadExternalImages: loadExternalImages
                )
            }
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Toggle(isOn: $loadExternalImages) {
                    Label("Load Images", systemImage: "photo")
                }
                .help("Load external images")

                Divider()

                Button {
                    reply()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                .keyboardShortcut("r", modifiers: .command)

                Button {
                    replyAll()
                } label: {
                    Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button {
                    forward()
                } label: {
                    Label("Forward", systemImage: "arrowshape.turn.up.right")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        .onAppear {
            // Mark as read when viewed
            if !message.isRead {
                message.markAsRead(true)
                // TODO: Sync with IMAP
            }
        }
    }

    // MARK: - Actions

    private func reply() {
        // TODO: Open compose with reply
        openWindow(id: "compose")
    }

    private func replyAll() {
        // TODO: Open compose with reply all
        openWindow(id: "compose")
    }

    private func forward() {
        // TODO: Open compose with forward
        openWindow(id: "compose")
    }
}

/// Message header showing from, to, date, subject.
struct MessageHeaderView: View {
    let message: Message

    @State private var showAllRecipients = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subject
            HStack {
                Text(message.subject)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textSelection(.enabled)

                Spacer()

                if message.isFlagged {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.orange)
                }
            }

            // From
            HStack(alignment: .top) {
                Text("From:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)

                VStack(alignment: .leading) {
                    if let name = message.fromName, !name.isEmpty {
                        Text(name)
                            .fontWeight(.medium)
                    }
                    Text(message.fromAddress)
                        .foregroundStyle(.secondary)
                }
                .textSelection(.enabled)

                Spacer()

                Text(message.date.mailDetailFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // To
            HStack(alignment: .top) {
                Text("To:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)

                if showAllRecipients || message.toAddresses.count <= 2 {
                    VStack(alignment: .leading) {
                        ForEach(message.toAddresses, id: \.self) { address in
                            Text(address)
                                .textSelection(.enabled)
                        }
                    }
                } else {
                    Button {
                        showAllRecipients = true
                    } label: {
                        Text("\(message.toAddresses.first ?? ""), and \(message.toAddresses.count - 1) more...")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }

            // CC
            if !message.ccAddresses.isEmpty {
                HStack(alignment: .top) {
                    Text("Cc:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    VStack(alignment: .leading) {
                        ForEach(message.ccAddresses, id: \.self) { address in
                            Text(address)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}

/// Bar showing attachments with download options.
struct AttachmentBarView: View {
    let attachments: [Attachment]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "paperclip")
                    Text("\(attachments.count) Attachment\(attachments.count == 1 ? "" : "s")")
                        .fontWeight(.medium)
                    Text("(\(totalSize))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    ForEach(attachments) { attachment in
                        AttachmentItemView(attachment: attachment)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var totalSize: String {
        let total = attachments.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }
}

/// Single attachment item with icon and actions.
struct AttachmentItemView: View {
    let attachment: Attachment

    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: attachment.iconName)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(attachment.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(attachment.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovering {
                Button {
                    saveAttachment()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func saveAttachment() {
        // TODO: Download attachment and save
    }
}

/// View for rendering message body content.
struct MessageBodyView: View {
    let message: Message
    let loadExternalImages: Bool

    var body: some View {
        if let html = message.bodyHtml, !html.isEmpty {
            HTMLContentView(html: html, loadExternalImages: loadExternalImages)
                .frame(minHeight: 300)
        } else if let text = message.bodyText, !text.isEmpty {
            Text(text)
                .textSelection(.enabled)
                .font(.body)
        } else {
            Text("No content")
                .foregroundStyle(.secondary)
                .italic()
        }
    }
}

/// WebView for rendering HTML email content.
struct HTMLContentView: NSViewRepresentable {
    let html: String
    let loadExternalImages: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Wrap HTML with basic styling
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    color: #333;
                    margin: 0;
                    padding: 0;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                a {
                    color: #007AFF;
                }
                blockquote {
                    border-left: 3px solid #ccc;
                    margin-left: 0;
                    padding-left: 10px;
                    color: #666;
                }
                \(loadExternalImages ? "" : "img[src^='http'] { display: none; }")
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """

        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // Open links in external browser
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}

// MARK: - Previews

#Preview {
    let message = Message(
        uid: 1,
        subject: "Welcome to RealMail - Your New Email Experience",
        fromAddress: "hello@realmail.app",
        fromName: "RealMail Team",
        toAddresses: ["user@example.com"],
        ccAddresses: ["team@example.com"],
        date: Date(),
        bodyText: "Thank you for trying RealMail!\n\nWe're excited to have you on board.",
        bodyHtml: "<p>Thank you for trying <strong>RealMail</strong>!</p><p>We're excited to have you on board.</p>",
        isRead: true,
        isFlagged: true,
        hasAttachments: true
    )

    let attachment = Attachment(
        filename: "welcome.pdf",
        mimeType: "application/pdf",
        size: 125000,
        message: message
    )
    message.attachments = [attachment]

    return MessageDetailView(message: message)
        .frame(width: 600, height: 600)
}
