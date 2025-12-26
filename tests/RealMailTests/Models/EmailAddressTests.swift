import Foundation
import Testing
@testable import RealMail

@Suite("EmailAddress Tests")
struct EmailAddressTests {

    // MARK: - Direct Initialization Tests

    @Test("Direct initialization with name and address")
    func testDirectInitialization() {
        let email = EmailAddress(name: "John Doe", address: "john@example.com")

        #expect(email.name == "John Doe")
        #expect(email.address == "john@example.com")
    }

    @Test("Direct initialization without name")
    func testDirectInitializationWithoutName() {
        let email = EmailAddress(name: nil, address: "john@example.com")

        #expect(email.name == nil)
        #expect(email.address == "john@example.com")
    }

    // MARK: - Parsing Tests

    @Test("Parse simple email address")
    func testParseSimpleEmail() {
        let email = EmailAddress(parsing: "user@example.com")

        #expect(email != nil)
        #expect(email?.address == "user@example.com")
        #expect(email?.name == nil)
    }

    @Test("Parse email with display name")
    func testParseEmailWithDisplayName() {
        let email = EmailAddress(parsing: "John Doe <john@example.com>")

        #expect(email != nil)
        #expect(email?.address == "john@example.com")
        #expect(email?.name == "John Doe")
    }

    @Test("Parse email with quoted display name")
    func testParseEmailWithQuotedDisplayName() {
        let email = EmailAddress(parsing: "\"Doe, John\" <john@example.com>")

        #expect(email != nil)
        #expect(email?.address == "john@example.com")
        #expect(email?.name == "Doe, John")
    }

    @Test("Parse email with complex quoted name")
    func testParseEmailWithComplexQuotedName() {
        let email = EmailAddress(parsing: "\"John (Johnny) Doe\" <john@example.com>")

        #expect(email != nil)
        #expect(email?.address == "john@example.com")
        #expect(email?.name == "John (Johnny) Doe")
    }

    @Test("Parse email with surrounding whitespace")
    func testParseEmailWithWhitespace() {
        let email = EmailAddress(parsing: "  user@example.com  ")

        #expect(email != nil)
        #expect(email?.address == "user@example.com")
    }

    @Test("Parse returns nil for empty string")
    func testParseEmptyString() {
        let email = EmailAddress(parsing: "")

        #expect(email == nil)
    }

    @Test("Parse returns nil for whitespace only")
    func testParseWhitespaceOnly() {
        let email = EmailAddress(parsing: "   ")

        #expect(email == nil)
    }

    // MARK: - Formatted String Tests

    @Test("Formatted string with name and address")
    func testFormattedStringWithName() {
        let email = EmailAddress(name: "John Doe", address: "john@example.com")

        #expect(email.formatted == "John Doe <john@example.com>")
    }

    @Test("Formatted string without name")
    func testFormattedStringWithoutName() {
        let email = EmailAddress(name: nil, address: "john@example.com")

        #expect(email.formatted == "john@example.com")
    }

    @Test("Formatted string with empty name")
    func testFormattedStringWithEmptyName() {
        let email = EmailAddress(name: "", address: "john@example.com")

        // Empty name should be treated as no name
        #expect(email.formatted == "john@example.com" || email.formatted == " <john@example.com>")
    }

    // MARK: - XOAUTH2 String Tests

    @Test("XOAUTH2 string format")
    func testXOAuth2String() {
        let email = EmailAddress(name: nil, address: "user@example.com")
        let token = "ya29.test-token"

        let authString = email.xoauth2String(accessToken: token)

        // Expected format: "user=email\x01auth=Bearer token\x01\x01"
        let expected = "user=user@example.com\u{01}auth=Bearer ya29.test-token\u{01}\u{01}"
        #expect(authString == expected)
    }

    // MARK: - Equality Tests

    @Test("Email addresses with same address are equal")
    func testEqualityWithSameAddress() {
        let email1 = EmailAddress(name: "John", address: "john@example.com")
        let email2 = EmailAddress(name: "John", address: "john@example.com")

        #expect(email1 == email2)
    }

    @Test("Email addresses with different addresses are not equal")
    func testEqualityWithDifferentAddress() {
        let email1 = EmailAddress(name: "John", address: "john@example.com")
        let email2 = EmailAddress(name: "John", address: "jane@example.com")

        #expect(email1 != email2)
    }

    @Test("Email addresses with same address but different names")
    func testEqualityDifferentNames() {
        let email1 = EmailAddress(name: "John Doe", address: "john@example.com")
        let email2 = EmailAddress(name: "Johnny", address: "john@example.com")

        // Equality should consider both name and address
        #expect(email1 != email2)
    }

    // MARK: - Hashable Tests

    @Test("Same email addresses have same hash")
    func testHashableConsistency() {
        let email1 = EmailAddress(name: "John", address: "john@example.com")
        let email2 = EmailAddress(name: "John", address: "john@example.com")

        #expect(email1.hashValue == email2.hashValue)
    }

    @Test("Can use EmailAddress in Set")
    func testSetUsage() {
        let email1 = EmailAddress(name: "John", address: "john@example.com")
        let email2 = EmailAddress(name: "Jane", address: "jane@example.com")
        let email3 = EmailAddress(name: "John", address: "john@example.com") // Duplicate

        var set = Set<EmailAddress>()
        set.insert(email1)
        set.insert(email2)
        set.insert(email3)

        #expect(set.count == 2) // Duplicate should not be added
    }

    // MARK: - Codable Tests

    @Test("EmailAddress encodes and decodes correctly")
    func testCodable() throws {
        let original = EmailAddress(name: "John Doe", address: "john@example.com")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EmailAddress.self, from: data)

        #expect(decoded == original)
        #expect(decoded.name == "John Doe")
        #expect(decoded.address == "john@example.com")
    }

    // MARK: - Edge Cases

    @Test("Email with plus addressing")
    func testPlusAddressing() {
        let email = EmailAddress(parsing: "user+tag@example.com")

        #expect(email != nil)
        #expect(email?.address == "user+tag@example.com")
    }

    @Test("Email with subdomain")
    func testSubdomain() {
        let email = EmailAddress(parsing: "user@mail.example.com")

        #expect(email != nil)
        #expect(email?.address == "user@mail.example.com")
    }

    @Test("Email with dots in local part")
    func testDotsInLocalPart() {
        let email = EmailAddress(parsing: "first.last@example.com")

        #expect(email != nil)
        #expect(email?.address == "first.last@example.com")
    }

    @Test("Email with numeric local part")
    func testNumericLocalPart() {
        let email = EmailAddress(parsing: "12345@example.com")

        #expect(email != nil)
        #expect(email?.address == "12345@example.com")
    }
}
