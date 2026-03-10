import SwiftUI
import UserNotifications

/// A multi-step onboarding sheet shown on first launch.
///
/// Guides the user through dependency detection, notification permissions,
/// and initial configuration before starting monitoring.
struct OnboardingView: View {

    /// The shared application state store.
    let appState: AppStateStore

    /// Callback invoked when onboarding is complete.
    let onComplete: () -> Void

    /// The current onboarding step (0-indexed).
    @State private var currentStep = 0

    /// The detected chezmoi binary path, if found.
    @State private var detectedChezmoiPath: String?

    /// The detected git binary path, if found.
    @State private var detectedGitPath: String?

    /// The detected source repo path, if found.
    @State private var detectedSourceRepoPath: String?

    /// Whether notification authorization was granted.
    @State private var notificationAuthorized = false

    /// Whether dependency detection has been performed.
    @State private var hasDetected = false

    /// Total number of onboarding steps.
    private static let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    dependenciesStep
                case 2:
                    permissionsStep
                case 3:
                    doneStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Step indicator and navigation
            HStack {
                stepIndicator

                Spacer()

                navigationButtons
            }
            .padding()
        }
        .frame(width: 520, height: 420)
    } // End of computed property body

    // MARK: - Step 1: Welcome

    /// Welcome step explaining what the app does.
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Welcome to Chezmoi Sync Monitor")
                .font(.title)
                .fontWeight(.bold)

            Text("A lightweight menu bar utility that monitors your chezmoi-managed dotfiles for sync state across machines. It detects local drift, remote drift, and conflict risks, providing contextual actions to resolve them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    } // End of computed property welcomeStep

    // MARK: - Step 2: Dependencies

    /// Dependency check step that auto-detects chezmoi, git, and source repo.
    private var dependenciesStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Check Dependencies")
                .font(.title2)
                .fontWeight(.bold)

            Text("The app needs chezmoi and git to be installed on your system.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                dependencyRow(
                    name: "chezmoi",
                    path: detectedChezmoiPath,
                    installURL: "https://www.chezmoi.io/install/"
                )

                dependencyRow(
                    name: "git",
                    path: detectedGitPath,
                    installURL: "https://git-scm.com/download/mac"
                )

                dependencyRow(
                    name: "Source repository",
                    path: detectedSourceRepoPath,
                    installURL: nil
                )
            }
            .padding(.horizontal, 40)

            if !hasDetected {
                Button("Detect") {
                    detectDependencies()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Re-detect") {
                    detectDependencies()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if !hasDetected {
                detectDependencies()
            }
        }
    } // End of computed property dependenciesStep

    // MARK: - Step 3: Permissions

    /// Permissions step requesting notification authorization.
    private var permissionsStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Notifications")
                .font(.title2)
                .fontWeight(.bold)

            Text("The app can notify you when drift or conflicts are detected in your dotfiles. This helps you stay aware of changes that need attention.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            if notificationAuthorized {
                Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Enable Notifications") {
                    Task {
                        await requestNotificationPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    } // End of computed property permissionsStep

    // MARK: - Step 4: Done

    /// Final summary step before starting monitoring.
    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're All Set")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                summaryRow("chezmoi", value: detectedChezmoiPath ?? "Not found")
                summaryRow("git", value: detectedGitPath ?? "Not found")
                summaryRow("Source repo", value: detectedSourceRepoPath ?? "Not found")
                summaryRow("Notifications", value: notificationAuthorized ? "Enabled" : "Disabled")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    } // End of computed property doneStep

    // MARK: - Navigation

    /// Dot indicators showing current step progress.
    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<OnboardingView.totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            } // End of ForEach step indicators
        }
    } // End of computed property stepIndicator

    /// Back/Next/Done navigation buttons.
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }

            if currentStep < OnboardingView.totalSteps - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Start Monitoring") {
                    appState.completeOnboarding()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    } // End of computed property navigationButtons

    // MARK: - Helper Views

    /// A row showing a dependency name with a checkmark or warning icon and its path.
    /// - Parameters:
    ///   - name: The dependency display name.
    ///   - path: The detected path, or nil if not found.
    ///   - installURL: An optional URL string for installation instructions.
    @ViewBuilder
    private func dependencyRow(name: String, path: String?, installURL: String?) -> some View {
        HStack(spacing: 10) {
            if path != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(.medium)

                if let path = path {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let urlString = installURL {
                    Link("Install instructions", destination: URL(string: urlString)!)
                        .font(.caption)
                } else {
                    Text("Not found — run 'chezmoi init' first")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    } // End of func dependencyRow(name:path:installURL:)

    /// A summary row showing a label and its value.
    /// - Parameters:
    ///   - label: The configuration item name.
    ///   - value: The detected value string.
    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    } // End of func summaryRow(_:value:)

    // MARK: - Actions

    /// Detects all dependencies and updates state.
    private func detectDependencies() {
        detectedChezmoiPath = PATHResolver.chezmoiPath()
        detectedGitPath = PATHResolver.gitPath()
        detectSourceRepoPath()
        hasDetected = true
    } // End of func detectDependencies()

    /// Detects the source repo path by running chezmoi source-path.
    private func detectSourceRepoPath() {
        guard let chezmoiBinary = detectedChezmoiPath ?? PATHResolver.chezmoiPath() else {
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

    /// Requests notification permission from the system.
    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                notificationAuthorized = granted
            }
        } catch {
            await MainActor.run {
                notificationAuthorized = false
            }
        }
    } // End of func requestNotificationPermission()
} // End of struct OnboardingView
