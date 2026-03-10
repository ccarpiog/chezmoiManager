import SwiftUI

/// Represents the synchronization state of a single file managed by chezmoi.
///
/// Each state carries a precedence value used for ordering: clean is lowest,
/// error is highest. This allows aggregate computations like "worst state."
enum FileSyncState: Int, Comparable, Hashable, Sendable {
    case clean = 0
    case localDrift = 1
    case remoteDrift = 2
    case dualDrift = 3
    case error = 4

    /// Compares two sync states by their precedence (raw value).
    /// - Parameters:
    ///   - lhs: The left-hand side state.
    ///   - rhs: The right-hand side state.
    /// - Returns: `true` if `lhs` has a lower precedence than `rhs`.
    static func < (lhs: FileSyncState, rhs: FileSyncState) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// A human-readable display name for the sync state (English).
    var displayName: String {
        switch self {
        case .clean:
            return String(localized: "state.clean", defaultValue: "Clean")
        case .localDrift:
            return String(localized: "state.localDrift", defaultValue: "Local Drift")
        case .remoteDrift:
            return String(localized: "state.remoteDrift", defaultValue: "Remote Drift")
        case .dualDrift:
            return String(localized: "state.dualDrift", defaultValue: "Dual Drift")
        case .error:
            return String(localized: "state.error", defaultValue: "Error")
        }
    } // End of computed property displayName

    /// The SF Symbol icon name representing this state.
    var iconName: String {
        switch self {
        case .clean:
            return "checkmark.circle.fill"
        case .localDrift:
            return "arrow.up.circle.fill"
        case .remoteDrift:
            return "arrow.down.circle.fill"
        case .dualDrift:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    } // End of computed property iconName

    /// The color associated with this state for UI rendering.
    var color: Color {
        switch self {
        case .clean:
            return .green
        case .localDrift:
            return .blue
        case .remoteDrift:
            return .orange
        case .dualDrift:
            return .red
        case .error:
            return .gray
        }
    } // End of computed property color
} // End of enum FileSyncState
