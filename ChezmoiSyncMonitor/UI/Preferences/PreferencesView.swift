import SwiftUI
import ServiceManagement
import AppKit

/// The main Preferences window with tabbed sections for Sync, Tools, and Advanced settings.
///
/// Changes are saved immediately via `AppStateStore.updatePreferences(_:)`.
struct PreferencesView: View {

    /// The shared application state store.
    let appState: AppStateStore

    /// Local copy of preferences for editing. Synced back to appState on every change.
    @State private var prefs: AppPreferences = .defaults

    /// Whether the reset confirmation dialog is showing.
    @State private var showingResetConfirmation = false

    /// The auto-detected chezmoi path, if found.
    @State private var detectedChezmoiPath: String?

    /// The auto-detected git path, if found.
    @State private var detectedGitPath: String?

    /// The auto-detected source repo path, if found.
    @State private var detectedSourceRepoPath: String?

    /// Current registration status for the app login item service.
    @State private var loginItemStatus: SMAppService.Status = .notRegistered

    /// Optional error message from the most recent login-item action.
    @State private var loginItemErrorMessage: String?

    /// Common poll interval options for the Picker.
    private static let pollIntervalOptions: [(label: String, value: Int)] = [
        ("1 min", 1),
        ("2 min", 2),
        ("5 min", 5),
        ("10 min", 10),
        ("15 min", 15),
        ("30 min", 30),
        ("60 min", 60),
        ("Manual only", 0)
    ]

    var body: some View {
        TabView {
            syncSettingsTab
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

            toolsTab
                .tabItem {
                    Label("Tools", systemImage: "wrench")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 480, height: 380)
        .onAppear {
            prefs = appState.preferences
            detectedChezmoiPath = PATHResolver.chezmoiPath()
            detectedGitPath = PATHResolver.gitPath()
            detectSourceRepoPath()
            refreshLoginItemStatus()
        }
    } // End of computed property body

    // MARK: - Sync Settings Tab

    /// Tab for configuring polling, fetch, batch sync, and notification settings.
    private var syncSettingsTab: some View {
        Form {
            Section("Polling") {
                Picker("Poll interval:", selection: Binding(
                    get: { prefs.pollIntervalMinutes },
                    set: { newValue in
                        prefs.pollIntervalMinutes = newValue
                        savePreferences()
                    }
                )) {
                    ForEach(PreferencesView.pollIntervalOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    } // End of ForEach poll interval options
                }
                .pickerStyle(.menu)
            }

            Section("Behavior") {
                Toggle("Auto-fetch on refresh", isOn: Binding(
                    get: { prefs.autoFetchEnabled },
                    set: { newValue in
                        prefs.autoFetchEnabled = newValue
                        savePreferences()
                    }
                ))

                Toggle("Batch safe sync", isOn: Binding(
                    get: { prefs.batchSafeSyncEnabled },
                    set: { newValue in
                        prefs.batchSafeSyncEnabled = newValue
                        savePreferences()
                    }
                ))
                .help("Enable \"Add All Safe\" to include batch operations")
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: Binding(
                    get: { prefs.notificationsEnabled },
                    set: { newValue in
                        prefs.notificationsEnabled = newValue
                        savePreferences()
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    } // End of computed property syncSettingsTab

    // MARK: - Tools Tab

    /// Tab for configuring tool paths (chezmoi, git, source repo, editor, merge tool).
    private var toolsTab: some View {
        Form {
            Section("Chezmoi") {
                HStack {
                    TextField("Chezmoi path:", text: Binding(
                        get: { prefs.chezmoiPathOverride ?? "" },
                        set: { newValue in
                            prefs.chezmoiPathOverride = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button("Auto-detect") {
                        let detected = PATHResolver.chezmoiPath()
                        detectedChezmoiPath = detected
                        prefs.chezmoiPathOverride = detected
                        savePreferences()
                    }
                }

                if let path = detectedChezmoiPath {
                    Text("Detected: \(path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not found")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Git") {
                HStack {
                    TextField("Git path:", text: Binding(
                        get: { prefs.gitPathOverride ?? "" },
                        set: { newValue in
                            prefs.gitPathOverride = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button("Auto-detect") {
                        let detected = PATHResolver.gitPath()
                        detectedGitPath = detected
                        prefs.gitPathOverride = detected
                        savePreferences()
                    }
                }

                if let path = detectedGitPath {
                    Text("Detected: \(path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not found")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Source Repository") {
                HStack {
                    TextField("Source repo path:", text: Binding(
                        get: { prefs.sourceRepoPathOverride ?? "" },
                        set: { newValue in
                            prefs.sourceRepoPathOverride = newValue.isEmpty ? nil : newValue
                            savePreferences()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button("Auto-detect") {
                        detectSourceRepoPath()
                        prefs.sourceRepoPathOverride = detectedSourceRepoPath
                        savePreferences()
                    }
                }

                if let path = detectedSourceRepoPath {
                    Text("Detected: \(path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not found — is chezmoi initialized?")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("External Tools") {
                TextField("Preferred editor:", text: Binding(
                    get: { prefs.preferredEditor ?? "" },
                    set: { newValue in
                        prefs.preferredEditor = newValue.isEmpty ? nil : newValue
                        savePreferences()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .help("e.g., code, vim, nano")

                TextField("Preferred merge tool:", text: Binding(
                    get: { prefs.preferredMergeTool ?? "" },
                    set: { newValue in
                        prefs.preferredMergeTool = newValue.isEmpty ? nil : newValue
                        savePreferences()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .help("e.g., opendiff, vimdiff")
            }
        }
        .formStyle(.grouped)
        .padding()
    } // End of computed property toolsTab

    // MARK: - Advanced Tab

    /// Tab for login at startup and reset settings.
    private var advancedTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { prefs.launchAtLogin },
                    set: { newValue in
                        prefs.launchAtLogin = newValue
                        savePreferences()
                        updateLoginItem(enabled: newValue)
                    }
                ))

                loginItemStatusView
            }

            Section("Reset") {
                Button("Reset All Settings", role: .destructive) {
                    showingResetConfirmation = true
                }
                .confirmationDialog(
                    "Reset all settings to defaults?",
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        appState.resetAllPreferences()
                        prefs = .defaults
                        updateLoginItem(enabled: false)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will restore all preferences to their default values. This action cannot be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    } // End of computed property advancedTab

    // MARK: - Helpers

    /// Saves the local prefs copy to the app state store.
    private func savePreferences() {
        appState.updatePreferences(prefs)
    } // End of func savePreferences()

    /// UI helper that describes the current login item status and next action.
    @ViewBuilder
    private var loginItemStatusView: some View {
        switch loginItemStatus {
        case .enabled:
            Text("Login item is enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .notRegistered:
            Text("Login item is disabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .requiresApproval:
            VStack(alignment: .leading, spacing: 6) {
                Text("Approval required in System Settings > General > Login Items.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Open Login Items Settings") {
                    openLoginItemsSettings()
                }
                .buttonStyle(.link)
            }
        case .notFound:
            Text("Login item helper not found in this build.")
                .font(.caption)
                .foregroundStyle(.red)
        @unknown default:
            Text("Login item status unavailable.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let errorMessage = loginItemErrorMessage {
            Text("Last startup toggle error: \(errorMessage)")
                .font(.caption)
                .foregroundStyle(.red)
        }
    } // End of computed property loginItemStatusView

    /// Updates the login item registration via SMAppService.
    /// - Parameter enabled: Whether to register or unregister the login item.
    private func updateLoginItem(enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                // Re-register on enable so app updates replace stale helper registrations.
                if service.status == .enabled {
                    try? service.unregister()
                }
                try service.register()
            } else {
                if service.status == .enabled || service.status == .requiresApproval {
                    try service.unregister()
                }
            }
            loginItemErrorMessage = nil
        } catch {
            loginItemErrorMessage = error.localizedDescription
        }

        refreshLoginItemStatus()
    } // End of func updateLoginItem(enabled:)

    /// Refreshes the cached `SMAppService` status used by the startup UI.
    private func refreshLoginItemStatus() {
        loginItemStatus = SMAppService.mainApp.status
    } // End of func refreshLoginItemStatus()

    /// Opens the Login Items pane to let users approve a newly registered item.
    private func openLoginItemsSettings() {
        let settingsURLs = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.users?LoginItems"
        ]

        for rawURL in settingsURLs {
            if let url = URL(string: rawURL), NSWorkspace.shared.open(url) {
                return
            }
        }
    } // End of func openLoginItemsSettings()

    /// Detects the source repo path by running chezmoi source-path.
    private func detectSourceRepoPath() {
        guard let chezmoiBinary = PATHResolver.chezmoiPath() else {
            detectedSourceRepoPath = nil
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: chezmoiBinary)
        process.arguments = ["source-path"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    detectedSourceRepoPath = path
                    return
                }
            }
        } catch {
            // Fall through to nil
        }

        detectedSourceRepoPath = nil
    } // End of func detectSourceRepoPath()
} // End of struct PreferencesView
