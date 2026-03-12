import Foundation

/// An immutable snapshot of the current synchronization state across all
/// chezmoi-managed files.
///
/// Counts are computed from the `files` array to avoid invariant drift.
struct SyncSnapshot: Sendable {
    /// The timestamp of the last successful refresh.
    let lastRefreshAt: Date?

    /// Individual file statuses included in this snapshot.
    let files: [FileStatus]

    /// Number of files with local-only changes.
    var localDriftCount: Int {
        files.filter { $0.state == .localDrift }.count
    }

    /// Number of files with remote-only changes.
    var remoteDriftCount: Int {
        files.filter { $0.state == .remoteDrift }.count
    }

    /// Number of files with changes on both sides (dual drift / conflict).
    var conflictCount: Int {
        files.filter { $0.state == .dualDrift }.count
    }

    /// Number of files in an error state.
    var errorCount: Int {
        files.filter { $0.state == .error }.count
    }

    /// Number of tracked files that are clean (no drift).
    var cleanCount: Int {
        files.filter { $0.state == .clean }.count
    }

    /// Number of files that currently require attention (non-clean).
    var needsAttentionCount: Int {
        files.filter { $0.state != .clean }.count
    }

    /// The worst (highest-precedence) sync state across all files.
    ///
    /// Returns `.clean` if there are no files.
    var overallState: FileSyncState {
        return files.map(\.state).max() ?? .clean
    }

    /// An empty snapshot representing a fresh, unrefreshed state.
    static let empty = SyncSnapshot(
        lastRefreshAt: nil,
        files: []
    )
} // End of struct SyncSnapshot
