import Foundation

/// Represents the current state of the background refresh cycle.
///
/// Tracks whether a refresh is in progress, succeeded, failed, or has become
/// stale (exceeded the expected polling interval).
enum RefreshState: Sendable {
    /// No refresh is in progress and no result is available yet.
    case idle

    /// A refresh operation is currently running.
    case running

    /// The last refresh completed successfully at the given date.
    case success(Date)

    /// The last refresh failed with the given error.
    case error(AppError)

    /// The data is stale because no refresh has completed within the expected interval.
    case stale
} // End of enum RefreshState
