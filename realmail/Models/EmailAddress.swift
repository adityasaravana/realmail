import Foundation

/// Value type for parsing and formatting email addresses per RFC 5322.
struct EmailAddress: Codable, Hashable, Sendable {
    /// Display name (e.g., "John Doe").
    let name: String?

    /// Email address (e.g., "john@example.com").
    let address: String

    /// Creates an EmailAddress with optional display name.
    init(name: String? = nil, address: String) {
        self.name = name?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        self.address = address.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Parses an email address string in various formats.
    ///
    /// Supported formats:
    /// - "john@example.com"
    /// - "<john@example.com>"
    /// - "John Doe <john@example.com>"
    /// - "\"John Doe\" <john@example.com>"
    init?(parsing string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Pattern: "Name" <email> or Name <email>
        if let range = trimmed.range(of: "<[^>]+>", options: .regularExpression) {
            let addressPart = String(trimmed[range])
                .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                .trimmingCharacters(in: .whitespaces)

            guard addressPart.isValidEmail else { return nil }

            let namePart = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .trimmingCharacters(in: .whitespaces)

            self.init(name: namePart.nilIfEmpty, address: addressPart)
        } else if trimmed.isValidEmail {
            // Plain email address
            self.init(address: trimmed)
        } else {
            return nil
        }
    }

    /// Parses a comma-separated list of email addresses.
    static func parseList(_ string: String) -> [EmailAddress] {
        // Split by comma, but be careful about commas in quoted names
        var addresses: [EmailAddress] = []
        var current = ""
        var inQuotes = false
        var inAngleBrackets = false

        for char in string {
            switch char {
            case "\"":
                inQuotes.toggle()
                current.append(char)
            case "<":
                inAngleBrackets = true
                current.append(char)
            case ">":
                inAngleBrackets = false
                current.append(char)
            case ",":
                if inQuotes || inAngleBrackets {
                    current.append(char)
                } else {
                    if let addr = EmailAddress(parsing: current) {
                        addresses.append(addr)
                    }
                    current = ""
                }
            default:
                current.append(char)
            }
        }

        // Don't forget the last address
        if let addr = EmailAddress(parsing: current) {
            addresses.append(addr)
        }

        return addresses
    }

    /// Formats as RFC 5322 string: "Name" <address> or just address.
    var formatted: String {
        if let name = name, !name.isEmpty {
            // Check if name needs quoting
            let needsQuotes = name.contains(where: { $0 == "," || $0 == "\"" || $0 == "<" || $0 == ">" })
            if needsQuotes {
                let escapedName = name.replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escapedName)\" <\(address)>"
            }
            return "\(name) <\(address)>"
        }
        return address
    }

    /// Display string: name if available, otherwise address.
    var displayString: String {
        name ?? address
    }

    /// Short display: name if available, otherwise local part of address.
    var shortDisplayString: String {
        if let name = name {
            return name
        }
        return address.components(separatedBy: "@").first ?? address
    }

    /// Domain part of the email address.
    var domain: String? {
        let parts = address.components(separatedBy: "@")
        return parts.count == 2 ? parts[1] : nil
    }

    /// Local part of the email address (before @).
    var localPart: String {
        address.components(separatedBy: "@").first ?? address
    }
}

// MARK: - CustomStringConvertible

extension EmailAddress: CustomStringConvertible {
    var description: String {
        formatted
    }
}

// MARK: - Equatable

extension EmailAddress: Equatable {
    static func == (lhs: EmailAddress, rhs: EmailAddress) -> Bool {
        // Email addresses are case-insensitive for comparison
        lhs.address.lowercased() == rhs.address.lowercased()
    }
}

// MARK: - Array Extensions

extension Array where Element == EmailAddress {
    /// Formats an array of email addresses as a comma-separated string.
    var formattedList: String {
        map(\.formatted).joined(separator: ", ")
    }

    /// Gets just the address strings.
    var addressStrings: [String] {
        map(\.address)
    }

    /// Creates an EmailAddress array from address strings.
    static func from(addresses: [String]) -> [EmailAddress] {
        addresses.compactMap { EmailAddress(parsing: $0) }
    }
}

// MARK: - Helper Extension

private extension String {
    /// Returns nil if the string is empty.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
