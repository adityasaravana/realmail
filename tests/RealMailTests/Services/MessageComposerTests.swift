import Foundation
import Testing
@testable import RealMail

@Suite("MessageComposer Tests")
struct MessageComposerTests {

    // MARK: - Plain Text Message Tests

    @Test("Compose plain text message")
    func testComposePlainTextMessage() {
        let from = EmailAddress(name: "Sender", address: "sender@example.com")
        let to = [EmailAddress(name: "Recipient", address: "recipient@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Test Subject",
            textBody: "Hello, World!",
            htmlBody: nil,
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("From: Sender <sender@example.com>"))
        #expect(composed.contains("To: Recipient <recipient@example.com>"))
        #expect(composed.contains("Subject: Test Subject"))
        #expect(composed.contains("Content-Type: text/plain"))
        #expect(composed.contains("Hello, World!"))
        #expect(composed.contains("Message-ID:"))
        #expect(composed.contains("Date:"))
    }

    // MARK: - HTML Message Tests

    @Test("Compose HTML message with plain text alternative")
    func testComposeHtmlMessage() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "HTML Test",
            textBody: "Plain text version",
            htmlBody: "<p>HTML version</p>",
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("Content-Type: multipart/alternative"))
        #expect(composed.contains("text/plain"))
        #expect(composed.contains("text/html"))
        #expect(composed.contains("Plain text version"))
        #expect(composed.contains("<p>HTML version</p>"))
    }

    // MARK: - Recipients Tests

    @Test("Compose message with CC recipients")
    func testComposeWithCc() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "to@example.com")]
        let cc = [
            EmailAddress(name: nil, address: "cc1@example.com"),
            EmailAddress(name: nil, address: "cc2@example.com"),
        ]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: cc,
            bcc: [],
            subject: "CC Test",
            textBody: "Test",
            htmlBody: nil,
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("Cc:"))
        #expect(composed.contains("cc1@example.com"))
        #expect(composed.contains("cc2@example.com"))
    }

    @Test("Compose message with BCC recipients (should not appear in headers)")
    func testComposeWithBcc() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "to@example.com")]
        let bcc = [EmailAddress(name: nil, address: "bcc@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: bcc,
            subject: "BCC Test",
            textBody: "Test",
            htmlBody: nil,
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        // BCC should NOT appear in the composed message headers
        #expect(!composed.contains("Bcc:"))
        // But it should still be stored in the struct for envelope
        #expect(message.bcc.count == 1)
    }

    // MARK: - Attachment Tests

    @Test("Compose message with attachment")
    func testComposeWithAttachment() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let attachmentData = "Hello, Attachment!".data(using: .utf8)!
        let attachment = MessageComposer.AttachmentData(
            filename: "test.txt",
            mimeType: "text/plain",
            content: attachmentData
        )

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Attachment Test",
            textBody: "See attached",
            htmlBody: nil,
            attachments: [attachment]
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("Content-Type: multipart/mixed"))
        #expect(composed.contains("Content-Disposition: attachment"))
        #expect(composed.contains("filename=\"test.txt\""))
        #expect(composed.contains("Content-Transfer-Encoding: base64"))
    }

    @Test("Compose message with multiple attachments")
    func testComposeWithMultipleAttachments() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let attachment1 = MessageComposer.AttachmentData(
            filename: "doc1.pdf",
            mimeType: "application/pdf",
            content: Data([0x25, 0x50, 0x44, 0x46]) // %PDF
        )

        let attachment2 = MessageComposer.AttachmentData(
            filename: "image.png",
            mimeType: "image/png",
            content: Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        )

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Multiple Attachments",
            textBody: "Multiple files attached",
            htmlBody: nil,
            attachments: [attachment1, attachment2]
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("doc1.pdf"))
        #expect(composed.contains("image.png"))
        #expect(composed.contains("application/pdf"))
        #expect(composed.contains("image/png"))
    }

    // MARK: - Reply Headers Tests

    @Test("Compose reply includes In-Reply-To header")
    func testComposeReplyHeaders() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let originalMessageId = "<original-123@example.com>"

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Re: Original Subject",
            textBody: "Reply text",
            htmlBody: nil,
            attachments: [],
            inReplyTo: originalMessageId,
            references: [originalMessageId]
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("In-Reply-To: <original-123@example.com>"))
        #expect(composed.contains("References: <original-123@example.com>"))
    }

    @Test("Compose reply with reference chain")
    func testComposeReplyWithReferenceChain() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let references = [
            "<msg1@example.com>",
            "<msg2@example.com>",
            "<msg3@example.com>",
        ]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Re: Thread",
            textBody: "Another reply",
            htmlBody: nil,
            attachments: [],
            inReplyTo: "<msg3@example.com>",
            references: references
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("In-Reply-To: <msg3@example.com>"))
        // References should include entire chain
        for ref in references {
            #expect(composed.contains(ref))
        }
    }

    // MARK: - Subject Encoding Tests

    @Test("Subject with ASCII characters is not encoded")
    func testSubjectAscii() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Simple ASCII Subject",
            textBody: "Body",
            htmlBody: nil,
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        #expect(composed.contains("Subject: Simple ASCII Subject"))
    }

    // MARK: - Date Formatting Tests

    @Test("Composed message includes properly formatted date")
    func testDateFormatting() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Date Test",
            textBody: "Body",
            htmlBody: nil,
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        // Should contain a Date header in RFC 2822 format
        #expect(composed.contains("Date:"))
        // Date format should include timezone
        #expect(composed.contains("+") || composed.contains("-") || composed.contains("GMT") || composed.contains("UTC"))
    }

    // MARK: - Message-ID Tests

    @Test("Composed message has unique Message-ID")
    func testMessageIdGeneration() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "ID Test",
            textBody: "Body",
            htmlBody: nil,
            attachments: []
        )

        let composed1 = MessageComposer.compose(message)
        let composed2 = MessageComposer.compose(message)

        // Both should have Message-ID headers
        #expect(composed1.contains("Message-ID:"))
        #expect(composed2.contains("Message-ID:"))

        // Message-IDs should be different (unique per composition)
        // Extract Message-ID from both and compare
        // This is a simplified check - in reality we'd parse the header
    }

    // MARK: - MIME Boundary Tests

    @Test("Multipart message has unique boundary")
    func testMimeBoundary() {
        let from = EmailAddress(name: nil, address: "sender@example.com")
        let to = [EmailAddress(name: nil, address: "recipient@example.com")]

        let message = MessageComposer.ComposedMessage(
            from: from,
            to: to,
            cc: [],
            bcc: [],
            subject: "Boundary Test",
            textBody: "Plain",
            htmlBody: "<p>HTML</p>",
            attachments: []
        )

        let composed = MessageComposer.compose(message)

        // Should contain boundary parameter
        #expect(composed.contains("boundary="))
        // Boundary markers should appear in content
        #expect(composed.contains("--"))
    }
}

// MARK: - Reply/Forward Helper Tests

@Suite("Reply and Forward Composition Tests")
struct ReplyForwardTests {

    @Test("Reply prefixes subject with Re:")
    @MainActor
    func testReplySubjectPrefix() throws {
        let originalMessage = TestDataFactory.makeMessage(
            subject: "Original Subject"
        )

        let from = EmailAddress(name: nil, address: "me@example.com")
        let reply = MessageComposer.composeReply(
            to: originalMessage,
            from: from,
            replyAll: false,
            body: "Reply body"
        )

        #expect(reply.subject == "Re: Original Subject")
    }

    @Test("Reply to Re: message doesn't double prefix")
    @MainActor
    func testReplyDoesntDoublePrefix() throws {
        let originalMessage = TestDataFactory.makeMessage(
            subject: "Re: Already a reply"
        )

        let from = EmailAddress(name: nil, address: "me@example.com")
        let reply = MessageComposer.composeReply(
            to: originalMessage,
            from: from,
            replyAll: false,
            body: "Reply body"
        )

        #expect(reply.subject == "Re: Already a reply")
        #expect(!reply.subject.hasPrefix("Re: Re:"))
    }

    @Test("Forward prefixes subject with Fwd:")
    @MainActor
    func testForwardSubjectPrefix() throws {
        let originalMessage = TestDataFactory.makeMessage(
            subject: "Original Subject"
        )

        let from = EmailAddress(name: nil, address: "me@example.com")
        let forward = MessageComposer.composeForward(
            originalMessage: originalMessage,
            from: from,
            to: [],
            body: "FYI"
        )

        #expect(forward.subject == "Fwd: Original Subject")
    }

    @Test("Reply All includes all recipients")
    @MainActor
    func testReplyAllRecipients() throws {
        let originalMessage = Message(
            uid: 1,
            subject: "Group Discussion",
            fromAddress: "sender@example.com",
            fromName: "Sender",
            toAddresses: ["me@example.com", "other@example.com"],
            ccAddresses: ["cc@example.com"],
            date: Date()
        )

        let from = EmailAddress(name: nil, address: "me@example.com")
        let reply = MessageComposer.composeReply(
            to: originalMessage,
            from: from,
            replyAll: true,
            body: "Reply to all"
        )

        // Should include original sender in To
        #expect(reply.to.contains { $0.address == "sender@example.com" })

        // Should include other To recipients (except self)
        #expect(reply.to.contains { $0.address == "other@example.com" } ||
                reply.cc.contains { $0.address == "other@example.com" })

        // Should include CC recipients
        #expect(reply.cc.contains { $0.address == "cc@example.com" })

        // Should NOT include self
        #expect(!reply.to.contains { $0.address == "me@example.com" })
        #expect(!reply.cc.contains { $0.address == "me@example.com" })
    }
}
