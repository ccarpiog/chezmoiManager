import Foundation

/// Application-level errors that can occur during chezmoi or git operations.
///
/// Conforms to `LocalizedError` to provide user-facing descriptions for each
/// error case.
enum AppError: Error, LocalizedError, Sendable {
    /// A CLI command failed with a non-zero exit code.
    case cliFailure(command: String, exitCode: Int32, stderr: String)

    /// Authentication failed (e.g., SSH key or token issue).
    case authError(String)

    /// The remote repository is unreachable (network or URL issue).
    case repoUnreachable(String)

    /// Failed to parse the output of a CLI command.
    case parseFailure(String)

    /// An unknown or uncategorized error.
    case unknown(String)

    /// A localized description of the error suitable for display.
    var errorDescription: String? {
        switch self {
        case .cliFailure(let command, let exitCode, let stderr):
            return String(
                localized: "error.cliFailure",
                defaultValue: "Command '\(command)' failed with exit code \(exitCode): \(stderr)"
            )
        case .authError(let detail):
            return String(
                localized: "error.authError",
                defaultValue: "Authentication error: \(detail)"
            )
        case .repoUnreachable(let detail):
            return String(
                localized: "error.repoUnreachable",
                defaultValue: "Repository unreachable: \(detail)"
            )
        case .parseFailure(let detail):
            return String(
                localized: "error.parseFailure",
                defaultValue: "Failed to parse output: \(detail)"
            )
        case .unknown(let detail):
            return String(
                localized: "error.unknown",
                defaultValue: "Unknown error: \(detail)"
            )
        }
    } // End of computed property errorDescription
} // End of enum AppError
