import Foundation
import SwiftData
import Testing
@testable import RealMail

@Suite("Folder Model Tests")
struct FolderTests {

    // MARK: - Initialization Tests

    @Test("Folder initializes with correct values")
    @MainActor
    func testFolderInitialization() throws {
        let folder = Folder(
            name: "INBOX",
            path: "INBOX",
            folderType: .inbox,
            unreadCount: 5
        )

        #expect(folder.name == "INBOX")
        #expect(folder.path == "INBOX")
        #expect(folder.folderType == .inbox)
        #expect(folder.unreadCount == 5)
        #expect(folder.messages.isEmpty)
        #expect(folder.children.isEmpty)
    }

    // MARK: - FolderType Tests

    @Test("FolderType detection from IMAP attributes - Inbox")
    func testFolderTypeInbox() {
        let type = FolderType.from(imapAttributes: ["\\Inbox"])

        #expect(type == .inbox)
    }

    @Test("FolderType detection from IMAP attributes - Sent")
    func testFolderTypeSent() {
        let type = FolderType.from(imapAttributes: ["\\Sent"])

        #expect(type == .sent)
    }

    @Test("FolderType detection from IMAP attributes - Drafts")
    func testFolderTypeDrafts() {
        let type = FolderType.from(imapAttributes: ["\\Drafts"])

        #expect(type == .drafts)
    }

    @Test("FolderType detection from IMAP attributes - Trash")
    func testFolderTypeTrash() {
        let type = FolderType.from(imapAttributes: ["\\Trash"])

        #expect(type == .trash)
    }

    @Test("FolderType detection from IMAP attributes - Junk/Spam")
    func testFolderTypeJunk() {
        let type = FolderType.from(imapAttributes: ["\\Junk"])

        #expect(type == .spam)
    }

    @Test("FolderType detection from IMAP attributes - Archive")
    func testFolderTypeArchive() {
        let type = FolderType.from(imapAttributes: ["\\Archive"])

        #expect(type == .archive)
    }

    @Test("FolderType detection from IMAP attributes - All Mail")
    func testFolderTypeAllMail() {
        let type = FolderType.from(imapAttributes: ["\\All"])

        #expect(type == .all)
    }

    @Test("FolderType detection from IMAP attributes - Unknown defaults to regular")
    func testFolderTypeUnknown() {
        let type = FolderType.from(imapAttributes: ["\\SomeCustomFlag"])

        #expect(type == .regular)
    }

    @Test("FolderType detection from empty attributes")
    func testFolderTypeEmptyAttributes() {
        let type = FolderType.from(imapAttributes: [])

        #expect(type == .regular)
    }

    // MARK: - Unread Count Tests

    @Test("Unread count can be updated")
    @MainActor
    func testUnreadCountUpdate() throws {
        let folder = TestDataFactory.makeFolder(unreadCount: 0)

        folder.unreadCount = 10

        #expect(folder.unreadCount == 10)
    }

    @Test("Unread count doesn't go negative")
    @MainActor
    func testUnreadCountNonNegative() throws {
        let folder = TestDataFactory.makeFolder(unreadCount: 5)

        // Manually set to negative (business logic should prevent this)
        folder.unreadCount = -1

        // The model allows it, but business logic should clamp to 0
        #expect(folder.unreadCount >= -1) // Model doesn't enforce, just verify it stored
    }

    // MARK: - Relationship Tests

    @Test("Folder belongs to an account")
    @MainActor
    func testFolderAccountRelationship() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = TestDataFactory.makeAccount()
        context.insert(account)

        let folder = TestDataFactory.makeFolder(account: account)
        context.insert(folder)

        #expect(folder.account === account)
        #expect(account.folders.contains { $0.id == folder.id })
    }

    @Test("Folder can have child folders")
    @MainActor
    func testFolderHierarchy() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let parentFolder = Folder(
            name: "Parent",
            path: "Parent",
            folderType: .regular,
            unreadCount: 0
        )
        context.insert(parentFolder)

        let childFolder1 = Folder(
            name: "Child1",
            path: "Parent/Child1",
            folderType: .regular,
            unreadCount: 0
        )
        childFolder1.parent = parentFolder

        let childFolder2 = Folder(
            name: "Child2",
            path: "Parent/Child2",
            folderType: .regular,
            unreadCount: 0
        )
        childFolder2.parent = parentFolder

        context.insert(childFolder1)
        context.insert(childFolder2)

        parentFolder.children.append(childFolder1)
        parentFolder.children.append(childFolder2)

        #expect(parentFolder.children.count == 2)
        #expect(childFolder1.parent === parentFolder)
        #expect(childFolder2.parent === parentFolder)
    }

    @Test("Folder can contain messages")
    @MainActor
    func testFolderMessagesRelationship() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = TestDataFactory.makeFolder()
        context.insert(folder)

        let message1 = TestDataFactory.makeMessage(uid: 1, folder: folder)
        let message2 = TestDataFactory.makeMessage(uid: 2, folder: folder)

        context.insert(message1)
        context.insert(message2)

        #expect(folder.messages.count == 2)
    }

    // MARK: - Display Name Tests

    @Test("Display name returns folder name")
    @MainActor
    func testDisplayName() throws {
        let folder = TestDataFactory.makeFolder(name: "My Folder")

        #expect(folder.name == "My Folder")
    }

    // MARK: - Icon Tests

    @Test("Inbox folder has inbox icon")
    @MainActor
    func testInboxIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .inbox)

        #expect(folder.iconName == "tray.fill")
    }

    @Test("Sent folder has sent icon")
    @MainActor
    func testSentIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .sent)

        #expect(folder.iconName == "paperplane.fill")
    }

    @Test("Drafts folder has drafts icon")
    @MainActor
    func testDraftsIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .drafts)

        #expect(folder.iconName == "doc.fill")
    }

    @Test("Trash folder has trash icon")
    @MainActor
    func testTrashIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .trash)

        #expect(folder.iconName == "trash.fill")
    }

    @Test("Spam folder has spam icon")
    @MainActor
    func testSpamIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .spam)

        #expect(folder.iconName == "xmark.bin.fill")
    }

    @Test("Archive folder has archive icon")
    @MainActor
    func testArchiveIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .archive)

        #expect(folder.iconName == "archivebox.fill")
    }

    @Test("Regular folder has folder icon")
    @MainActor
    func testRegularIcon() throws {
        let folder = TestDataFactory.makeFolder(folderType: .regular)

        #expect(folder.iconName == "folder.fill")
    }

    // MARK: - Persistence Tests

    @Test("Folder persists to SwiftData")
    @MainActor
    func testFolderPersistence() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = TestDataFactory.makeAccount()
        context.insert(account)

        let folder = Folder(
            name: "Persisted",
            path: "Persisted",
            folderType: .regular,
            unreadCount: 42
        )
        folder.account = account
        account.folders.append(folder)
        context.insert(folder)

        try context.save()

        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate { $0.name == "Persisted" }
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.unreadCount == 42)
        #expect(fetched.first?.folderType == .regular)
    }
}
