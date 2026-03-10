import SwiftUI

/// View displayed in the menu bar dropdown (window-style popover).
///
/// Shows a status summary, per-state file counts, quick actions
/// (refresh, add local, commit & push, apply remote), and navigation
/// to the dashboard and preferences.
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    /// The shared application state store.
    let appState: AppStateStore

    /// Whether a refresh operation is currently in progress.
    private var isRefreshing: Bool {
        if case .running = appState.refreshState { return true }
        return false
    }

    /// The text to display for the last refresh timestamp.
    private var lastRefreshText: String {
        if isRefreshing {
            return String(localized: "menu.refreshing",
                          defaultValue: "Refreshing...")
        }
        guard let date = appState.snapshot.lastRefreshAt else {
            return String(localized: "menu.never",
                          defaultValue: "Never")
        }
        return RelativeTimeFormatter.string(for: date)
    } // End of computed property lastRefreshText

    /// The status icon configuration based on current state.
    private var statusIcon: StatusIconProvider.IconConfig {
        StatusIconProvider.icon(
            for: appState.snapshot.overallState,
            refreshState: appState.refreshState,
            isOnline: appState.isOnline
        )
    }

    /// Whether there are any drifted files at all.
    private var hasAnyDrift: Bool {
        appState.snapshot.localDriftCount > 0
            || appState.snapshot.remoteDriftCount > 0
            || appState.snapshot.conflictCount > 0
            || appState.snapshot.errorCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Offline banner
            if !appState.isOnline {
                offlineBanner
                Divider()
                    .padding(.horizontal, 12)
            }

            // MARK: - Header section
            headerSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Count rows section
            countSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Actions section
            actionsSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Navigation section
            navigationSection

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Quit
            menuButton(
                String(localized: "menu.quit", defaultValue: "Quit"),
                icon: "power"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 280)
    } // End of computed property body

    // MARK: - Header

    /// The top header showing the app name with a status indicator and last refresh time.
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(nsImage: statusIcon.image)
                .foregroundStyle(statusIcon.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "menu.title",
                            defaultValue: "Chezmoi Sync Monitor"))
                    .fontWeight(.semibold)
                Text("Last refresh: \(lastRefreshText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    } // End of computed property headerSection

    // MARK: - Offline banner

    /// A non-intrusive inline banner shown when the network is unreachable.
    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "menu.offline",
                            defaultValue: "Offline"))
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                if let lastRefresh = appState.snapshot.lastRefreshAt {
                    Text(String(
                        localized: "menu.lastCheck",
                        defaultValue: "Last check: \(RelativeTimeFormatter.string(for: lastRefresh))"
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    } // End of computed property offlineBanner

    // MARK: - Counts

    /// Rows showing per-state file counts, only visible when count > 0.
    private var countSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.snapshot.localDriftCount > 0 {
                countRow(
                    icon: FileSyncState.localDrift.iconName,
                    color: FileSyncState.localDrift.color,
                    count: appState.snapshot.localDriftCount,
                    labelSingular: String(localized: "menu.localChange",
                                          defaultValue: "local change"),
                    labelPlural: String(localized: "menu.localChanges",
                                        defaultValue: "local changes")
                )
            }

            if appState.snapshot.remoteDriftCount > 0 {
                countRow(
                    icon: FileSyncState.remoteDrift.iconName,
                    color: FileSyncState.remoteDrift.color,
                    count: appState.snapshot.remoteDriftCount,
                    labelSingular: String(localized: "menu.remoteChange",
                                          defaultValue: "remote change"),
                    labelPlural: String(localized: "menu.remoteChanges",
                                        defaultValue: "remote changes")
                )
            }

            if appState.snapshot.conflictCount > 0 {
                countRow(
                    icon: FileSyncState.dualDrift.iconName,
                    color: FileSyncState.dualDrift.color,
                    count: appState.snapshot.conflictCount,
                    labelSingular: String(localized: "menu.conflict",
                                          defaultValue: "conflict"),
                    labelPlural: String(localized: "menu.conflicts",
                                        defaultValue: "conflicts")
                )
            }

            if appState.snapshot.errorCount > 0 {
                countRow(
                    icon: FileSyncState.error.iconName,
                    color: FileSyncState.error.color,
                    count: appState.snapshot.errorCount,
                    labelSingular: String(localized: "menu.error",
                                          defaultValue: "error"),
                    labelPlural: String(localized: "menu.errors",
                                        defaultValue: "errors")
                )
            }

            // Show "all clean" message when nothing is drifted
            if !hasAnyDrift {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text(String(localized: "menu.allClean",
                                defaultValue: "All files in sync"))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 2)
    } // End of computed property countSection

    // MARK: - Actions

    /// Quick action buttons: refresh, add local changes, commit & push, apply remote.
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuButton(
                String(localized: "menu.refreshNow",
                       defaultValue: "Refresh Now"),
                icon: "arrow.clockwise",
                disabled: isRefreshing
            ) {
                Task { await appState.refresh() }
            }

            menuButton(
                String(localized: "menu.addLocalChanges",
                       defaultValue: "Add Local Changes"),
                icon: "plus.circle",
                disabled: appState.snapshot.localDriftCount == 0 || isRefreshing
            ) {
                Task { await appState.addAllSafe() }
            }

            menuButton(
                String(localized: "menu.commitAndPush",
                       defaultValue: "Commit & Push"),
                icon: "arrow.up.circle",
                disabled: isRefreshing
            ) {
                Task { await appState.commitAndPush() }
            }

            menuButton(
                String(localized: "menu.applySafeRemote",
                       defaultValue: "Apply Safe Remote"),
                icon: "arrow.down.circle",
                disabled: appState.snapshot.remoteDriftCount == 0 || isRefreshing
            ) {
                Task { await appState.updateSafe() }
            }
        }
    } // End of computed property actionsSection

    // MARK: - Navigation

    /// Links to the dashboard window and preferences.
    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuButton(
                String(localized: "menu.openDashboard",
                       defaultValue: "Open Dashboard"),
                icon: "rectangle.grid.1x2"
            ) {
                openWindow(id: "dashboard")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            menuButton(
                String(localized: "menu.preferences",
                       defaultValue: "Preferences..."),
                icon: "gearshape"
            ) {
                openPreferences()
            }
        }
    } // End of computed property navigationSection

    // MARK: - Helpers

    /// Opens the macOS Settings/Preferences window programmatically.
    private func openPreferences() {
        openSettings()
        NSApplication.shared.activate(ignoringOtherApps: true)
    } // End of func openPreferences()

    /// Builds a single count row with an icon, count value, and singular/plural label.
    /// - Parameters:
    ///   - icon: The SF Symbol name for the row icon.
    ///   - color: The tint color for the icon.
    ///   - count: The number to display.
    ///   - labelSingular: The singular description text (e.g., "local change").
    ///   - labelPlural: The plural description text (e.g., "local changes").
    /// - Returns: A styled HStack view.
    private func countRow(
        icon: String,
        color: Color,
        count: Int,
        labelSingular: String,
        labelPlural: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count) \(count == 1 ? labelSingular : labelPlural)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    } // End of func countRow(icon:color:count:labelSingular:labelPlural:)

    /// A reusable button styled to look like a menu item with hover highlight.
    /// - Parameters:
    ///   - title: The button label text.
    ///   - icon: The SF Symbol name.
    ///   - disabled: Whether the button is disabled.
    ///   - action: The closure to run on tap.
    /// - Returns: A styled button view.
    private func menuButton(
        _ title: String,
        icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MenuItemButtonStyle())
        .disabled(disabled)
    } // End of func menuButton(_:icon:disabled:action:)
} // End of struct MenuBarView

/// A button style that mimics macOS menu item appearance with hover highlight.
struct MenuItemButtonStyle: ButtonStyle {
    @State private var isHovered = false

    /// Creates the styled button body with hover and press states.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed
                          ? Color.accentColor.opacity(0.3)
                          : isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
    } // End of func makeBody(configuration:)
} // End of struct MenuItemButtonStyle
