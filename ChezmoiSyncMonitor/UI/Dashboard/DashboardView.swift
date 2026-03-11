import SwiftUI

/// Represents the filter options available in the file list dropdown.
private enum FileFilter: CaseIterable {
    case all
    case localDrift
    case remoteDrift
    case dualDrift
    case error
    case clean

    /// The localized display name for the filter option.
    var displayName: String {
        switch self {
        case .all: return Strings.filters.all
        case .localDrift: return Strings.filters.localDrift
        case .remoteDrift: return Strings.filters.remoteDrift
        case .dualDrift: return Strings.filters.dualDrift
        case .error: return Strings.filters.error
        case .clean: return Strings.filters.clean
        }
    } // End of computed property displayName

    /// Maps the filter to the corresponding FileSyncState, if any.
    var syncState: FileSyncState? {
        switch self {
        case .all: return nil
        case .localDrift: return .localDrift
        case .remoteDrift: return .remoteDrift
        case .dualDrift: return .dualDrift
        case .error: return .error
        case .clean: return .clean
        }
    } // End of computed property syncState
} // End of enum FileFilter

/// Dashboard window showing an overview of chezmoi-managed dotfiles sync state.
///
/// Displays overview cards, a filterable file list with contextual actions,
/// a diff viewer sheet, and a collapsible activity log.
struct DashboardView: View {

    /// The shared application state store.
    let appState: AppStateStore

    /// The currently selected filter for the file list.
    @State private var selectedFilter: FileFilter = .all

    /// The search text for filtering files by path.
    @State private var searchText = ""

    /// The file path currently being diffed (drives the diff sheet).
    @State private var diffFilePath: String?

    /// Whether the diff viewer sheet is presented.
    @State private var showingDiff = false

    /// The file path pending a destructive apply confirmation.
    @State private var applyConfirmationPath: String?

    /// Whether the apply confirmation dialog is shown.
    @State private var showingApplyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header section
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // Overview cards
            overviewCards
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            // Filter and search bar
            filterBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // File list
            fileListSection
                .padding(.horizontal, 20)

            Spacer(minLength: 8)

            // Activity log
            ActivityLogView(events: appState.activityLog)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        } // End of outer VStack
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showingDiff) {
            if let path = diffFilePath, let diff = appState.currentDiff {
                DiffViewerView(filePath: path, diffText: diff)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(Strings.dashboard.diffLoadError)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button(Strings.navigation.close) { showingDiff = false }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .frame(minWidth: 400, minHeight: 200)
            }
        }
        .confirmationDialog(
            Strings.dashboard.applyRemoteChanges,
            isPresented: $showingApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(Strings.dashboard.apply, role: .destructive) {
                if let path = applyConfirmationPath {
                    Task {
                        await appState.updateSafe()
                        _ = path // updateSafe applies all remote changes
                    }
                }
            }
            Button(Strings.navigation.cancel, role: .cancel) {
                applyConfirmationPath = nil
            }
        } message: {
            Text(Strings.dashboard.applyWarning)
        }
    } // End of body

    // MARK: - Header Section

    /// The header showing the app title and refresh status indicator.
    private var headerSection: some View {
        HStack {
            Text(Strings.dashboard.title)
                .font(.title)
                .fontWeight(.semibold)

            Spacer()

            refreshStateIndicator

            Button {
                Task {
                    await appState.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        } // End of header HStack
    } // End of headerSection

    /// Displays the current refresh state as text or a spinner.
    @ViewBuilder
    private var refreshStateIndicator: some View {
        switch appState.refreshState {
        case .idle:
            Text(Strings.dashboard.notRefreshedYet)
                .font(.callout)
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(Strings.dashboard.refreshing)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .success(let date):
            Text(Strings.dashboard.lastRefresh(RelativeTimeFormatter.string(for: date)))
                .font(.callout)
                .foregroundStyle(.secondary)
        case .error(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        case .stale:
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text(Strings.dashboard.dataIsStale)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } // End of switch refreshState
    } // End of refreshStateIndicator

    /// Whether a refresh operation is currently running.
    private var isRefreshing: Bool {
        if case .running = appState.refreshState { return true }
        return false
    } // End of isRefreshing

    // MARK: - Overview Cards

    /// The horizontal row of overview cards showing aggregate counts.
    private var overviewCards: some View {
        HStack(spacing: 12) {
            OverviewCardView(
                iconName: FileSyncState.localDrift.iconName,
                count: appState.snapshot.localDriftCount,
                label: Strings.overviewCards.localDrift,
                color: FileSyncState.localDrift.color,
                isSelected: selectedFilter == .localDrift,
                action: { toggleFilter(.localDrift) }
            )

            OverviewCardView(
                iconName: FileSyncState.remoteDrift.iconName,
                count: appState.snapshot.remoteDriftCount,
                label: Strings.overviewCards.remoteDrift,
                color: FileSyncState.remoteDrift.color,
                isSelected: selectedFilter == .remoteDrift,
                action: { toggleFilter(.remoteDrift) }
            )

            OverviewCardView(
                iconName: FileSyncState.dualDrift.iconName,
                count: appState.snapshot.conflictCount,
                label: Strings.overviewCards.conflicts,
                color: FileSyncState.dualDrift.color,
                isSelected: selectedFilter == .dualDrift,
                action: { toggleFilter(.dualDrift) }
            )

            OverviewCardView(
                iconName: FileSyncState.error.iconName,
                count: appState.snapshot.errorCount,
                label: Strings.overviewCards.errors,
                color: FileSyncState.error.color,
                isSelected: selectedFilter == .error,
                action: { toggleFilter(.error) }
            )
        } // End of HStack for overview cards
    } // End of overviewCards

    /// Toggles a filter on or off; clicking an already-selected filter resets to "All".
    /// - Parameter filter: The filter to toggle.
    private func toggleFilter(_ filter: FileFilter) {
        if selectedFilter == filter {
            selectedFilter = .all
        } else {
            selectedFilter = filter
        }
    } // End of func toggleFilter(_:)

    // MARK: - Filter Bar

    /// The filter dropdown and search field above the file list.
    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(Strings.dashboard.filter)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedFilter) {
                    ForEach(FileFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                } // End of Picker
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            HStack(spacing: 6) {
                Text(Strings.dashboard.search)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField(Strings.dashboard.filterByPath, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        } // End of HStack for filter bar
    } // End of filterBar

    // MARK: - File List

    /// The filtered and searchable list of managed files.
    private var fileListSection: some View {
        GroupBox {
            if filteredFiles.isEmpty {
                emptyFileListView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFiles) { file in
                            FileListItemView(
                                file: file,
                                onAdd: { path in
                                    Task { await appState.addSingle(path: path) }
                                },
                                onApply: { path in
                                    applyConfirmationPath = path
                                    showingApplyConfirmation = true
                                },
                                onDiff: { path in
                                    diffFilePath = path
                                    Task {
                                        await appState.loadDiff(for: path)
                                        showingDiff = true
                                    }
                                },
                                onEdit: { path in
                                    appState.openInEditor(path: path)
                                },
                                onMerge: { path in
                                    Task { await appState.openInMergeTool(path: path) }
                                }
                            )

                            if file.id != filteredFiles.last?.id {
                                Divider()
                            }
                        } // End of ForEach over files
                    } // End of LazyVStack
                } // End of ScrollView
            } // End of else (files not empty)
        } label: {
            HStack {
                Text(Strings.dashboard.managedFiles)
                    .font(.headline)

                Text("(\(filteredFiles.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        } // End of GroupBox
    } // End of fileListSection

    /// The view shown when no files match the current filter/search.
    private var emptyFileListView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            if appState.snapshot.files.isEmpty {
                Text(Strings.dashboard.noManagedFiles)
                    .foregroundStyle(.secondary)
                Text(Strings.dashboard.clickRefresh)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(Strings.dashboard.noFilesMatchFilter)
                    .foregroundStyle(.secondary)
                Button(Strings.dashboard.clearFilters) {
                    selectedFilter = .all
                    searchText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } // End of VStack for empty state
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    } // End of emptyFileListView

    /// The files from the snapshot, filtered by the selected state filter and search text.
    private var filteredFiles: [FileStatus] {
        var files = appState.snapshot.files

        // Apply state filter
        if let state = selectedFilter.syncState {
            files = files.filter { $0.state == state }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            files = files.filter { $0.path.lowercased().contains(query) }
        }

        return files
    } // End of computed property filteredFiles
} // End of struct DashboardView
