import Foundation
import SwiftData
import Testing
@testable import RealMail

@Suite("Message Model Tests")
struct MessageTests {

    // MARK: - Initialization Tests

    @Test("Message initializes with correct values")
    @MainActor
    func testMessageInitialization() throws {
        let date = Date()
        let message = TestDataFactory.makeMessage(
            uid: 42,
            subject: "Test Email",
            fromAddress: "sender@example.com",
            fromName: "Test Sender",
            toAddresses: ["recipient@example.com"],
            date: date,
            bodyText: "Hello, World!",
            isRead: false,
            isFlagged: true
        )

        #expect(message.uid == 42)
        #expect(message.subject == "Test Email")
        #expect(message.fromAddress == "sender@example.com")
        #expect(message.fromName == "Test Sender")
        #expect(message.toAddresses == ["recipient@example.com"])
        #expect(message.date == date)
        #expect(message.bodyText == "Hello, World!")
        #expect(message.isRead == false)
        #expect(message.isFlagged == true)
    }

    // MARK: - Flag Operations

    @Test("Message can be marked as read")
    @MainActor
    func testMarkAsRead() throws {
        let message = TestDataFactory.makeMessage(isRead: false)

        #expect(message.isRead == false)

        message.markAsRead(true)

        #expect(message.isRead == true)
    }

    @Test("Message can be marked as unread")
    @MainActor
    func testMarkAsUnread() throws {
        let message = TestDataFactory.makeMessage(isRead: true)

        #expect(message.isRead == true)

        message.markAsRead(false)

        #expect(message.isRead == false)
    }

    @Test("Message can be flagged")
    @MainActor
    func testSetFlagged() throws {
        let message = TestDataFactory.makeMessage(isFlagged: false)

        #expect(message.isFlagged == false)

        message.setFlagged(true)

        #expect(message.isFlagged == true)
    }

    @Test("Message can be unflagged")
    @MainActor
    func testSetUnflagged() throws {
        let message = TestDataFactory.makeMessage(isFlagged: true)

        #expect(message.isFlagged == true)

        message.setFlagged(false)

        #expect(message.isFlagged == false)
    }

    // MARK: - Computed Properties

    @Test("Formatted sender shows name when available")
    @MainActor
    func testFormattedSenderWithName() throws {
        let message = TestDataFactory.makeMessage(
            fromAddress: "sender@example.com",
            fromName: "John Doe"
        )

        #expect(message.formattedSender == "John Doe")
    }

    @Test("Formatted sender shows email when name is missing")
    @MainActor
    func testFormattedSenderWithoutName() throws {
        let message = TestDataFactory.makeMessage(
            fromAddress: "sender@example.com",
            fromName: nil
        )

        #expect(message.formattedSender == "sender@example.com")
    }

    @Test("Formatted sender shows email when name is empty")
    @MainActor
    func testFormattedSenderWithEmptyName() throws {
        let message = Message(
            uid: 1,
            subject: "Test",
            fromAddress: "sender@example.com",
            fromName: "",
            toAddresses: ["to@example.com"],
            date: Date()
        )

        #expect(message.formattedSender == "sender@example.com")
    }

    // MARK: - Reply-To Tests

    @Test("effectiveReplyTo returns replyTo when available")
    @MainActor
    func testEffectiveReplyToWithReplyTo() throws {
        let message = Message(
            uid: 1,
            subject: "Test",
            fromAddress: "sender@example.com",
            toAddresses: ["to@example.com"],
            date: Date()
        )
        message.replyTo = "reply@example.com"

        #expect(message.effectiveReplyTo == "reply@example.com")
    }

    @Test("effectiveReplyTo falls back to fromAddress")
    @MainActor
    func testEffectiveReplyToFallback() throws {
        let message = TestDataFactory.makeMessage(fromAddress: "sender@example.com")
        message.replyTo = nil

        #expect(message.effectiveReplyTo == "sender@example.com")
    }

    // MARK: - Threading Tests

    @Test("Message can store message ID for threading")
    @MainActor
    func testMessageIdStorage() throws {
        let message = TestDataFactory.makeMessage()
        message.messageId = "<test-123@example.com>"

        #expect(message.messageId == "<test-123@example.com>")
    }

    @Test("Message can store In-Reply-To for threading")
    @MainActor
    func testInReplyToStorage() throws {
        let message = TestDataFactory.makeMessage()
        message.inReplyTo = "<original-123@example.com>"

        #expect(message.inReplyTo == "<original-123@example.com>")
    }

    @Test("Message can store References for threading")
    @MainActor
    func testReferencesStorage() throws {
        let message = TestDataFactory.makeMessage()
        message.references = ["<msg1@example.com>", "<msg2@example.com>"]

        #expect(message.references.count == 2)
        #expect(message.references.contains("<msg1@example.com>"))
        #expect(message.references.contains("<msg2@example.com>"))
    }

    // MARK: - Folder Relationship Tests

    @Test("Message belongs to a folder")
    @MainActor
    func testMessageFolderRelationship() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = TestDataFactory.makeAccount()
        context.insert(account)

        let folder = TestDataFactory.makeFolder(account: account)
        context.insert(folder)

        let message = TestDataFactory.makeMessage(folder: folder)
        context.insert(message)

        #expect(message.folder === folder)
        #expect(folder.messages.contains { $0.uid == message.uid })
    }

    // MARK: - Attachment Tests

    @Test("Message can have attachments")
    @MainActor
    func testMessageWithAttachments() throws {
        let message = TestDataFactory.makeMessage(hasAttachments: true)
        let attachment = TestDataFactory.makeAttachment(message: message)

        #expect(message.hasAttachments == true)
        #expect(message.attachments.count == 1)
        #expect(attachment.message === message)
    }

    // MARK: - Persistence Tests

    @Test("Message persists with folder relationship")
    @MainActor
    func testMessagePersistence() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = TestDataFactory.makeAccount()
        context.insert(account)

        let folder = TestDataFactory.makeFolder(name: "INBOX", account: account)
        context.insert(folder)

        let message = TestDataFactory.makeMessage(
            uid: 999,
            subject: "Persisted Message",
            folder: folder
        )
        context.insert(message)

        try context.save()

        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.uid == 999 }
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.subject == "Persisted Message")
        #expect(fetched.first?.folder?.name == "INBOX")
    }
}
