import Foundation
import SwiftData
import Testing

// MARK: - Test Container Factory

/// Creates an in-memory SwiftData ModelContainer for testing.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([
        Account.self,
        Folder.self,
        Message.self,
        Attachment.self,
    ])

    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: true
    )

    return try ModelContainer(for: schema, configurations: [configuration])
}

// MARK: - Test Data Factories

/// Factory methods for creating test data.
enum TestDataFactory {

    // MARK: - Account

    @MainActor
    static func makeAccount(
        email: String = "test@example.com",
        displayName: String = "Test User",
        provider: AccountProvider = .other,
        imapHost: String = "imap.example.com",
        smtpHost: String = "smtp.example.com",
        isEnabled: Bool = true
    ) -> Account {
        Account(
            email: email,
            displayName: displayName,
            provider: provider,
            imapHost: imapHost,
            imapPort: 993,
            smtpHost: smtpHost,
            smtpPort: 587,
            isEnabled: isEnabled
        )
    }

    // MARK: - Folder

    @MainActor
    static func makeFolder(
        name: String = "INBOX",
        path: String = "INBOX",
        folderType: FolderType = .inbox,
        unreadCount: Int = 0,
        account: Account? = nil
    ) -> Folder {
        let folder = Folder(
            name: name,
            path: path,
            folderType: folderType,
            unreadCount: unreadCount
        )
        if let account = account {
            folder.account = account
            account.folders.append(folder)
        }
        return folder
    }

    // MARK: - Message

    @MainActor
    static func makeMessage(
        uid: UInt32 = 1,
        subject: String = "Test Subject",
        fromAddress: String = "sender@example.com",
        fromName: String? = "Sender Name",
        toAddresses: [String] = ["recipient@example.com"],
        date: Date = Date(),
        bodyText: String? = "Test body text",
        bodyHtml: String? = nil,
        isRead: Bool = false,
        isFlagged: Bool = false,
        hasAttachments: Bool = false,
        folder: Folder? = nil
    ) -> Message {
        let message = Message(
            uid: uid,
            subject: subject,
            fromAddress: fromAddress,
            fromName: fromName,
            toAddresses: toAddresses,
            date: date,
            bodyText: bodyText,
            bodyHtml: bodyHtml,
            isRead: isRead,
            isFlagged: isFlagged,
            hasAttachments: hasAttachments
        )
        if let folder = folder {
            message.folder = folder
            folder.messages.append(message)
        }
        return message
    }

    // MARK: - Attachment

    @MainActor
    static func makeAttachment(
        filename: String = "document.pdf",
        mimeType: String = "application/pdf",
        size: Int = 1024,
        content: Data? = nil,
        message: Message? = nil
    ) -> Attachment {
        let attachment = Attachment(
            filename: filename,
            mimeType: mimeType,
            size: size,
            message: message
        )
        attachment.content = content
        if let message = message {
            message.attachments.append(attachment)
        }
        return attachment
    }

    // MARK: - Email Address

    static func makeEmailAddress(
        name: String? = nil,
        address: String = "test@example.com"
    ) -> EmailAddress {
        EmailAddress(name: name, address: address)
    }
}

// MARK: - Assertion Helpers

/// Asserts that two optional values are equal.
func expectEqual<T: Equatable>(_ lhs: T?, _ rhs: T?, _ comment: Comment? = nil) {
    #expect(lhs == rhs, comment)
}

/// Asserts that a throwing expression throws an error.
func expectThrows<T>(_ expression: @autoclosure () throws -> T, _ comment: Comment? = nil) {
    do {
        _ = try expression()
        Issue.record("Expected expression to throw, but it succeeded", sourceLocation: SourceLocation())
    } catch {
        // Expected
    }
}

/// Asserts that an async throwing expression throws an error.
func expectThrowsAsync<T>(_ expression: @autoclosure () async throws -> T, _ comment: Comment? = nil) async {
    do {
        _ = try await expression()
        Issue.record("Expected expression to throw, but it succeeded", sourceLocation: SourceLocation())
    } catch {
        // Expected
    }
}
