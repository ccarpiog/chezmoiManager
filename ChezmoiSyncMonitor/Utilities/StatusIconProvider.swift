import AppKit
import SwiftUI

/// Provides the appropriate menu bar icon as an `NSImage` based on the current
/// sync state, refresh state, and network connectivity.
///
/// Uses `MenuBarIconRenderer` to draw the custom chezmoi icon with state-specific
/// badge overlays. All images are template images for automatic light/dark adaptation.
enum StatusIconProvider {

    /// The icon configuration for the menu bar.
    struct IconConfig {
        /// The rendered menu bar icon as an NSImage (template).
        let image: NSImage
        /// The tint color hint for use in the dropdown menu (not applied to template icons).
        let color: Color
    } // End of struct IconConfig

    /// Computes the menu bar icon configuration from the current state.
    /// - Parameters:
    ///   - overallState: The worst sync state across all files.
    ///   - refreshState: The current refresh operation state.
    ///   - isOnline: Whether the network is currently reachable.
    /// - Returns: An `IconConfig` with the appropriate icon image and color hint.
    static func icon(
        for overallState: FileSyncState,
        refreshState: RefreshState,
        isOnline: Bool = true
    ) -> IconConfig {
        let image = MenuBarIconRenderer.icon(
            for: overallState,
            refreshState: refreshState,
            isOnline: isOnline
        )

        let color: Color
        if !isOnline {
            color = .secondary
        } else if case .running = refreshState {
            color = .primary
        } else {
            switch overallState {
            case .clean:
                color = .gray
            case .localDrift:
                color = .blue
            case .remoteDrift:
                color = .orange
            case .dualDrift, .error:
                color = .red
            }
        }

        return IconConfig(image: image, color: color)
    } // End of func icon(for:refreshState:isOnline:)
} // End of enum StatusIconProvider
