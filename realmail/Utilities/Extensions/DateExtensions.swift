import Foundation

extension Date {
    // MARK: - Email Date Formatting

    /// Formats the date for display in message lists.
    /// Shows time for today, day name for this week, and short date otherwise.
    var mailListFormat: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                  self > weekAgo {
            return formatted(.dateTime.weekday(.wide))
        } else if calendar.component(.year, from: self) == calendar.component(.year, from: Date()) {
            return formatted(.dateTime.month(.abbreviated).day())
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// Formats the date for display in message detail headers.
    var mailDetailFormat: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today at \(formatted(date: .omitted, time: .shortened))"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday at \(formatted(date: .omitted, time: .shortened))"
        } else {
            return formatted(date: .long, time: .shortened)
        }
    }

    /// Formats the date according to RFC 2822 for email headers.
    var rfc2822Format: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }

    // MARK: - Parsing

    /// Parses a date from RFC 2822 format used in email headers.
    /// - Parameter string: The date string in RFC 2822 format.
    /// - Returns: The parsed date, or nil if parsing fails.
    static func fromRFC2822(_ string: String) -> Date? {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss z",
            "dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss z",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // Try ISO 8601 as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: string)
    }

    // MARK: - Convenience

    /// Returns a relative description of when this date occurred.
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns true if this date is within the last 24 hours.
    var isRecent: Bool {
        timeIntervalSinceNow > -86400
    }
}
