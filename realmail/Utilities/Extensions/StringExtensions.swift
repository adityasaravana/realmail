import Foundation

extension String {
    // MARK: - Email Address Parsing

    /// Extracts the email address from a formatted string like "Name <email@example.com>".
    var extractedEmailAddress: String? {
        // Try to extract from angle brackets
        if let start = range(of: "<"),
           let end = range(of: ">", range: start.upperBound..<endIndex) {
            return String(self[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // Check if the whole string is a valid email
        if isValidEmail {
            return self
        }

        return nil
    }

    /// Extracts the display name from a formatted string like "Name <email@example.com>".
    var extractedDisplayName: String? {
        // Check for "Name <email>" format
        if let start = range(of: "<") {
            let name = String(self[..<start.lowerBound]).trimmingCharacters(in: .whitespaces)
            // Remove surrounding quotes if present
            if name.hasPrefix("\"") && name.hasSuffix("\"") {
                return String(name.dropFirst().dropLast())
            }
            return name.isEmpty ? nil : name
        }
        return nil
    }

    /// Returns true if this string appears to be a valid email address.
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: emailRegex, options: .regularExpression) != nil
    }

    // MARK: - Subject Normalization

    /// Returns the subject with "Re:", "Fwd:", etc. prefixes removed for threading.
    var normalizedSubject: String {
        var subject = self

        // Common reply/forward prefixes in various languages
        let prefixes = [
            "re:", "fwd:", "fw:",
            "aw:", // German
            "sv:", // Swedish
            "antw:", // Dutch
            "r:",  // Italian
        ]

        var changed = true
        while changed {
            changed = false
            let lower = subject.lowercased().trimmingCharacters(in: .whitespaces)

            for prefix in prefixes {
                if lower.hasPrefix(prefix) {
                    subject = String(subject.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    changed = true
                    break
                }
            }

            // Handle numbered replies like "Re[2]:" or "Re (2):"
            if let match = subject.range(of: #"^(Re|Fwd?)(\s*[\[\(]\d+[\]\)])?\s*:\s*"#,
                                         options: [.regularExpression, .caseInsensitive]) {
                subject = String(subject[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }

        return subject
    }

    // MARK: - MIME Helpers

    /// Decodes RFC 2047 encoded words in email headers.
    var decodedMIMEHeader: String {
        guard contains("=?") else { return self }

        var result = self
        let pattern = #"=\?([^?]+)\?([BQ])\?([^?]+)\?="#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return self
        }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let charsetRange = Range(match.range(at: 1), in: result),
                  let encodingRange = Range(match.range(at: 2), in: result),
                  let dataRange = Range(match.range(at: 3), in: result),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }

            let charset = String(result[charsetRange])
            let encoding = String(result[encodingRange]).uppercased()
            let encodedData = String(result[dataRange])

            var decoded: String?

            if encoding == "B" {
                // Base64 encoding
                if let data = Data(base64Encoded: encodedData),
                   let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString),
                   cfEncoding != kCFStringEncodingInvalidId {
                    let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                    decoded = String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
                }
            } else if encoding == "Q" {
                // Quoted-printable encoding
                let processed = encodedData
                    .replacingOccurrences(of: "_", with: " ")
                    .removingPercentEncoding
                decoded = processed
            }

            if let decoded = decoded {
                result.replaceSubrange(fullRange, with: decoded)
            }
        }

        return result
    }

    // MARK: - Message Preview

    /// Creates a snippet for message preview by cleaning up whitespace.
    /// - Parameter length: Maximum length of the snippet.
    /// - Returns: A cleaned up preview string.
    func messageSnippet(maxLength length: Int = AppConstants.UI.snippetLength) -> String {
        // Remove excessive whitespace
        let cleaned = components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if cleaned.count <= length {
            return cleaned
        }

        // Truncate at word boundary
        let truncated = String(cleaned.prefix(length))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "…"
        }
        return truncated + "…"
    }

    // MARK: - Encoding Helpers

    /// Returns the string encoded for safe use in IMAP commands.
    var imapQuoted: String {
        "\"" + replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
