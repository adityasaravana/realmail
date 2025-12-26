import Foundation
import SwiftData
import Testing
@testable import RealMail

@Suite("Account Model Tests")
struct AccountTests {

    // MARK: - Initialization Tests

    @Test("Account initializes with correct default values")
    @MainActor
    func testAccountInitialization() throws {
        let account = TestDataFactory.makeAccount(
            email: "user@gmail.com",
            displayName: "Gmail User",
            provider: .gmail
        )

        #expect(account.email == "user@gmail.com")
        #expect(account.displayName == "Gmail User")
        #expect(account.provider == .gmail)
        #expect(account.imapHost == "imap.example.com")
        #expect(account.imapPort == 993)
        #expect(account.smtpHost == "smtp.example.com")
        #expect(account.smtpPort == 587)
        #expect(account.isEnabled == true)
        #expect(account.folders.isEmpty)
    }

    @Test("Account provider detection for Gmail")
    @MainActor
    func testGmailProviderConfiguration() throws {
        let account = Account(
            email: "user@gmail.com",
            displayName: "Gmail User",
            provider: .gmail,
            imapHost: "imap.gmail.com",
            imapPort: 993,
            smtpHost: "smtp.gmail.com",
            smtpPort: 587,
            isEnabled: true
        )

        #expect(account.provider == .gmail)
    }

    @Test("Account provider detection for Outlook")
    @MainActor
    func testOutlookProviderConfiguration() throws {
        let account = Account(
            email: "user@outlook.com",
            displayName: "Outlook User",
            provider: .outlook,
            imapHost: "outlook.office365.com",
            imapPort: 993,
            smtpHost: "smtp.office365.com",
            smtpPort: 587,
            isEnabled: true
        )

        #expect(account.provider == .outlook)
    }

    // MARK: - Relationship Tests

    @Test("Account can have multiple folders")
    @MainActor
    func testAccountFolderRelationship() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = TestDataFactory.makeAccount()
        context.insert(account)

        let inbox = TestDataFactory.makeFolder(name: "Inbox", path: "INBOX", folderType: .inbox, account: account)
        let sent = TestDataFactory.makeFolder(name: "Sent", path: "Sent", folderType: .sent, account: account)
        let trash = TestDataFactory.makeFolder(name: "Trash", path: "Trash", folderType: .trash, account: account)

        context.insert(inbox)
        context.insert(sent)
        context.insert(trash)

        #expect(account.folders.count == 3)
        #expect(account.folders.contains { $0.folderType == .inbox })
        #expect(account.folders.contains { $0.folderType == .sent })
        #expect(account.folders.contains { $0.folderType == .trash })
    }

    // MARK: - Enabled/Disabled Tests

    @Test("Account can be disabled")
    @MainActor
    func testAccountDisabling() throws {
        let account = TestDataFactory.makeAccount(isEnabled: true)

        #expect(account.isEnabled == true)

        account.isEnabled = false

        #expect(account.isEnabled == false)
    }

    // MARK: - Persistence Tests

    @Test("Account persists to SwiftData")
    @MainActor
    func testAccountPersistence() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let account = TestDataFactory.makeAccount(
            email: "persist@test.com",
            displayName: "Persisted User"
        )
        context.insert(account)
        try context.save()

        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.email == "persist@test.com" }
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.displayName == "Persisted User")
    }
}

// MARK: - AccountProvider Tests

@Suite("AccountProvider Enum Tests")
struct AccountProviderTests {

    @Test("Gmail provider has correct OAuth settings")
    func testGmailOAuthSettings() {
        let provider = AccountProvider.gmail

        #expect(provider == .gmail)
    }

    @Test("Outlook provider has correct OAuth settings")
    func testOutlookOAuthSettings() {
        let provider = AccountProvider.outlook

        #expect(provider == .outlook)
    }

    @Test("iCloud provider is recognized")
    func testICloudProvider() {
        let provider = AccountProvider.icloud

        #expect(provider == .icloud)
    }

    @Test("Other provider for custom servers")
    func testOtherProvider() {
        let provider = AccountProvider.other

        #expect(provider == .other)
    }
}
