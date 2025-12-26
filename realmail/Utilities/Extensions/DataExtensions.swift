import Foundation

extension Data {
    // MARK: - MIME Encoding/Decoding

    /// Encodes the data as base64 with line breaks for MIME.
    /// - Parameter lineLength: Maximum line length (default 76 for MIME).
    /// - Returns: Base64 encoded string with proper line breaks.
    func base64EncodedMIMEString(lineLength: Int = 76) -> String {
        let base64 = base64EncodedString()
        var lines: [String] = []
        var index = base64.startIndex

        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: lineLength, limitedBy: base64.endIndex) ?? base64.endIndex
            lines.append(String(base64[index..<end]))
            index = end
        }

        return lines.joined(separator: "\r\n")
    }

    /// Decodes base64 data, handling MIME line breaks.
    /// - Parameter string: The base64 encoded string.
    /// - Returns: Decoded data, or nil if decoding fails.
    static func fromBase64MIME(_ string: String) -> Data? {
        // Remove whitespace and line breaks
        let cleaned = string.replacingOccurrences(of: "[\\r\\n\\s]", with: "", options: .regularExpression)
        return Data(base64Encoded: cleaned)
    }

    /// Decodes quoted-printable encoded data.
    /// - Parameter string: The quoted-printable encoded string.
    /// - Returns: Decoded data, or nil if decoding fails.
    static func fromQuotedPrintable(_ string: String) -> Data? {
        var result = Data()
        var index = string.startIndex

        while index < string.endIndex {
            let char = string[index]

            if char == "=" {
                // Check for soft line break
                let nextIndex = string.index(after: index)
                if nextIndex < string.endIndex {
                    let next = string[nextIndex]
                    if next == "\r" || next == "\n" {
                        // Soft line break - skip the = and the line break
                        index = string.index(after: nextIndex)
                        if index < string.endIndex && string[index] == "\n" {
                            index = string.index(after: index)
                        }
                        continue
                    }

                    // Hex encoded byte
                    if let secondNext = string.index(nextIndex, offsetBy: 1, limitedBy: string.endIndex) {
                        let hexChars = String(string[nextIndex..<secondNext]) + String(string[secondNext])
                        if let byte = UInt8(hexChars, radix: 16) {
                            result.append(byte)
                            index = string.index(after: secondNext)
                            continue
                        }
                    }
                }
            }

            // Regular character
            if let byte = char.asciiValue {
                result.append(byte)
            }
            index = string.index(after: index)
        }

        return result
    }

    // MARK: - Character Set Conversion

    /// Attempts to decode the data as a string using the specified charset.
    /// - Parameter charset: IANA charset name (e.g., "UTF-8", "ISO-8859-1").
    /// - Returns: Decoded string, or nil if conversion fails.
    func string(encoding charset: String) -> String? {
        // Handle common charset aliases
        let normalizedCharset = charset.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        // Try to get the encoding
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)

        if cfEncoding != kCFStringEncodingInvalidId {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return String(data: self, encoding: String.Encoding(rawValue: nsEncoding))
        }

        // Fallback mappings for common charsets
        let encodings: [String: String.Encoding] = [
            "UTF8": .utf8,
            "USASCII": .ascii,
            "ASCII": .ascii,
            "ISO88591": .isoLatin1,
            "LATIN1": .isoLatin1,
            "WINDOWS1252": .windowsCP1252,
            "CP1252": .windowsCP1252,
        ]

        if let encoding = encodings[normalizedCharset] {
            return String(data: self, encoding: encoding)
        }

        // Last resort: try UTF-8 with lossy conversion
        return String(data: self, encoding: .utf8)
            ?? String(data: self, encoding: .isoLatin1)
    }

    // MARK: - Helpers

    /// Returns a hex string representation of the data.
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    /// Creates data from a hex string.
    /// - Parameter hex: The hex string.
    /// - Returns: Data decoded from hex, or nil if invalid.
    static func fromHex(_ hex: String) -> Data? {
        var data = Data()
        var index = hex.startIndex

        while index < hex.endIndex {
            guard let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex),
                  let byte = UInt8(String(hex[index..<nextIndex]), radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        return data
    }
}
