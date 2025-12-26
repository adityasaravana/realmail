import Foundation

/// Composes MIME email messages.
struct MessageComposer {
    /// Message being composed.
    struct ComposedMessage {
        let from: EmailAddress
        let to: [EmailAddress]
        let cc: [EmailAddress]
        let bcc: [EmailAddress]
        let subject: String
        let textBody: String?
        let htmlBody: String?
        let attachments: [AttachmentData]
        let inReplyTo: String?
        let references: [String]
        let messageId: String

        init(
            from: EmailAddress,
            to: [EmailAddress],
            cc: [EmailAddress] = [],
            bcc: [EmailAddress] = [],
            subject: String,
            textBody: String? = nil,
            htmlBody: String? = nil,
            attachments: [AttachmentData] = [],
            inReplyTo: String? = nil,
            references: [String] = []
        ) {
            self.from = from
            self.to = to
            self.cc = cc
            self.bcc = bcc
            self.subject = subject
            self.textBody = textBody
            self.htmlBody = htmlBody
            self.attachments = attachments
            self.inReplyTo = inReplyTo
            self.references = references
            self.messageId = MessageComposer.generateMessageId(from: from.address)
        }

        /// All recipients for SMTP RCPT TO.
        var allRecipients: [String] {
            (to + cc + bcc).map(\.address)
        }
    }

    /// Attachment data for composing.
    struct AttachmentData {
        let filename: String
        let mimeType: String
        let content: Data
        let isInline: Bool
        let contentId: String?

        init(
            filename: String,
            mimeType: String,
            content: Data,
            isInline: Bool = false,
            contentId: String? = nil
        ) {
            self.filename = filename
            self.mimeType = mimeType
            self.content = content
            self.isInline = isInline
            self.contentId = contentId ?? (isInline ? UUID().uuidString : nil)
        }
    }

    // MARK: - Compose Methods

    /// Composes a MIME message from the given components.
    static func compose(_ message: ComposedMessage) -> String {
        var parts: [String] = []

        // Headers
        parts.append(buildHeaders(message))

        // Determine message structure
        let hasAttachments = !message.attachments.isEmpty
        let hasHtml = message.htmlBody != nil
        let hasText = message.textBody != nil

        if hasAttachments {
            // multipart/mixed for attachments
            let boundary = generateBoundary()
            parts.append("Content-Type: multipart/mixed; boundary=\"\(boundary)\"")
            parts.append("")
            parts.append("--\(boundary)")

            if hasHtml && hasText {
                // Nested multipart/alternative for text+html
                let altBoundary = generateBoundary()
                parts.append("Content-Type: multipart/alternative; boundary=\"\(altBoundary)\"")
                parts.append("")
                parts.append(buildAlternativePart(text: message.textBody!, html: message.htmlBody!, boundary: altBoundary))
            } else if hasHtml {
                parts.append(buildHtmlPart(message.htmlBody!))
            } else if hasText {
                parts.append(buildTextPart(message.textBody!))
            }

            // Add attachments
            for attachment in message.attachments {
                parts.append("--\(boundary)")
                parts.append(buildAttachmentPart(attachment))
            }

            parts.append("--\(boundary)--")
        } else if hasHtml && hasText {
            // multipart/alternative for text+html
            let boundary = generateBoundary()
            parts.append("Content-Type: multipart/alternative; boundary=\"\(boundary)\"")
            parts.append("")
            parts.append(buildAlternativePart(text: message.textBody!, html: message.htmlBody!, boundary: boundary))
        } else if hasHtml {
            parts.append(buildHtmlPart(message.htmlBody!))
        } else if hasText {
            parts.append(buildTextPart(message.textBody!))
        } else {
            // Empty message
            parts.append("Content-Type: text/plain; charset=utf-8")
            parts.append("")
            parts.append("")
        }

        return parts.joined(separator: "\r\n")
    }

    /// Creates a reply message.
    static func composeReply(
        to originalMessage: Message,
        from: EmailAddress,
        replyAll: Bool = false,
        body: String
    ) -> ComposedMessage {
        // Determine recipients
        var toRecipients = [EmailAddress(parsing: originalMessage.effectiveReplyTo)].compactMap { $0 }
        var ccRecipients: [EmailAddress] = []

        if replyAll {
            // Add original To recipients (except ourselves)
            let otherTos = originalMessage.toAddresses
                .compactMap { EmailAddress(parsing: $0) }
                .filter { $0.address != from.address }
            toRecipients.append(contentsOf: otherTos)

            // Add CC recipients
            ccRecipients = originalMessage.ccAddresses
                .compactMap { EmailAddress(parsing: $0) }
                .filter { $0.address != from.address }
        }

        // Build subject
        let subject = originalMessage.subject.hasPrefix("Re:") ?
            originalMessage.subject :
            "Re: \(originalMessage.subject)"

        // Build references chain
        var references = originalMessage.references
        if let messageId = originalMessage.messageId {
            references.append(messageId)
        }

        return ComposedMessage(
            from: from,
            to: toRecipients,
            cc: ccRecipients,
            subject: subject,
            textBody: body,
            inReplyTo: originalMessage.messageId,
            references: references
        )
    }

    /// Creates a forward message.
    static func composeForward(
        originalMessage: Message,
        from: EmailAddress,
        to: [EmailAddress],
        body: String,
        includeAttachments: Bool = true
    ) -> ComposedMessage {
        // Build subject
        let subject = originalMessage.subject.hasPrefix("Fwd:") ?
            originalMessage.subject :
            "Fwd: \(originalMessage.subject)"

        // Build forwarded body
        let forwardedContent = """
        \(body)

        ---------- Forwarded message ----------
        From: \(originalMessage.formattedSender) <\(originalMessage.fromAddress)>
        Date: \(originalMessage.date.formatted())
        Subject: \(originalMessage.subject)
        To: \(originalMessage.toAddresses.joined(separator: ", "))

        \(originalMessage.bodyText ?? "")
        """

        // Include attachments if requested
        var attachments: [AttachmentData] = []
        if includeAttachments {
            for attachment in originalMessage.attachments {
                if let content = attachment.content {
                    attachments.append(AttachmentData(
                        filename: attachment.filename,
                        mimeType: attachment.mimeType,
                        content: content
                    ))
                }
            }
        }

        return ComposedMessage(
            from: from,
            to: to,
            subject: subject,
            textBody: forwardedContent,
            attachments: attachments
        )
    }

    // MARK: - Private Helpers

    private static func buildHeaders(_ message: ComposedMessage) -> String {
        var headers: [String] = []

        // Standard headers
        headers.append("From: \(message.from.formatted)")
        headers.append("To: \(message.to.formattedList)")

        if !message.cc.isEmpty {
            headers.append("Cc: \(message.cc.formattedList)")
        }

        // Note: BCC is not included in headers (only used for RCPT TO)

        headers.append("Subject: \(encodeHeader(message.subject))")
        headers.append("Date: \(Date().rfc2822Format)")
        headers.append("Message-ID: <\(message.messageId)>")
        headers.append("MIME-Version: 1.0")

        // Threading headers
        if let inReplyTo = message.inReplyTo {
            headers.append("In-Reply-To: <\(inReplyTo)>")
        }

        if !message.references.isEmpty {
            let refs = message.references.map { "<\($0)>" }.joined(separator: " ")
            headers.append("References: \(refs)")
        }

        // User-Agent
        headers.append("X-Mailer: RealMail/1.0")

        return headers.joined(separator: "\r\n")
    }

    private static func buildTextPart(_ text: String) -> String {
        """
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: quoted-printable

        \(encodeQuotedPrintable(text))
        """
    }

    private static func buildHtmlPart(_ html: String) -> String {
        """
        Content-Type: text/html; charset=utf-8
        Content-Transfer-Encoding: quoted-printable

        \(encodeQuotedPrintable(html))
        """
    }

    private static func buildAlternativePart(text: String, html: String, boundary: String) -> String {
        """
        --\(boundary)
        \(buildTextPart(text))
        --\(boundary)
        \(buildHtmlPart(html))
        --\(boundary)--
        """
    }

    private static func buildAttachmentPart(_ attachment: AttachmentData) -> String {
        var headers: [String] = []

        headers.append("Content-Type: \(attachment.mimeType); name=\"\(attachment.filename)\"")
        headers.append("Content-Transfer-Encoding: base64")

        if attachment.isInline, let contentId = attachment.contentId {
            headers.append("Content-ID: <\(contentId)>")
            headers.append("Content-Disposition: inline; filename=\"\(attachment.filename)\"")
        } else {
            headers.append("Content-Disposition: attachment; filename=\"\(attachment.filename)\"")
        }

        let encodedContent = attachment.content.base64EncodedString(options: .lineLength76Characters)

        return headers.joined(separator: "\r\n") + "\r\n\r\n" + encodedContent
    }

    static func generateMessageId(from email: String) -> String {
        let uuid = UUID().uuidString.lowercased()
        let domain = email.components(separatedBy: "@").last ?? "localhost"
        return "\(uuid)@\(domain)"
    }

    private static func generateBoundary() -> String {
        "----=_Part_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    private static func encodeHeader(_ value: String) -> String {
        // Check if encoding is needed
        let needsEncoding = value.unicodeScalars.contains { $0.value > 127 }

        if needsEncoding {
            // Use RFC 2047 encoded-word syntax
            let encoded = Data(value.utf8).base64EncodedString()
            return "=?UTF-8?B?\(encoded)?="
        }

        return value
    }

    private static func encodeQuotedPrintable(_ text: String) -> String {
        var result = ""
        var lineLength = 0
        let maxLineLength = 76

        for char in text {
            let encoded: String
            let scalar = char.unicodeScalars.first!

            if char == "\r" || char == "\n" {
                result += String(char)
                lineLength = 0
                continue
            } else if (scalar.value >= 33 && scalar.value <= 126 && char != "=") || char == " " || char == "\t" {
                encoded = String(char)
            } else {
                // Encode as =XX
                let bytes = String(char).utf8
                encoded = bytes.map { String(format: "=%02X", $0) }.joined()
            }

            // Check line length
            if lineLength + encoded.count > maxLineLength - 1 {
                result += "=\r\n"
                lineLength = 0
            }

            result += encoded
            lineLength += encoded.count
        }

        return result
    }
}
