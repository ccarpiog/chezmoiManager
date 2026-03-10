import Foundation

/// The result of executing an external CLI command (chezmoi or git).
///
/// Captures the exit code, standard output and error streams, wall-clock
/// duration, and the command string for logging and diagnostics.
struct CommandResult: Sendable {
    /// The process exit code (0 typically means success).
    let exitCode: Int32

    /// The captured standard output.
    let stdout: String

    /// The captured standard error.
    let stderr: String

    /// How long the command took to execute, in seconds.
    let duration: TimeInterval

    /// The command string that was executed.
    let command: String

    /// Whether the command completed successfully (exit code 0).
    var isSuccess: Bool {
        return exitCode == 0
    }
} // End of struct CommandResult
