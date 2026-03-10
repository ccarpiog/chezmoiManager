import Foundation

/// Formats a `Date` into a human-readable relative time string.
///
/// Produces concise strings like "just now", "2 min ago", "1 hour ago",
/// "3 days ago", etc. Intended for menu bar status display.
enum RelativeTimeFormatter {

    /// Formats the given date into a relative time string compared to now.
    /// - Parameter date: The date to format.
    /// - Returns: A relative time string in English (externalizable for i18n).
    static func string(for date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Future dates or essentially "now"
        if interval < 5 {
            return "just now"
        }

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if seconds < 60 {
            return "\(seconds) sec ago"
        }

        if minutes == 1 {
            return "1 min ago"
        }

        if minutes < 60 {
            return "\(minutes) min ago"
        }

        if hours == 1 {
            return "1 hour ago"
        }

        if hours < 24 {
            return "\(hours) hours ago"
        }

        if days == 1 {
            return "1 day ago"
        }

        return "\(days) days ago"
    } // End of func string(for:)
} // End of enum RelativeTimeFormatter
