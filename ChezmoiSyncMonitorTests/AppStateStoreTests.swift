import XCTest
@testable import ChezmoiSyncMonitor

// MARK: - Mock Services

/// Mock implementation of ChezmoiServiceProtocol for testing.
final class MockChezmoiService: ChezmoiServiceProtocol, @unchecked Sendable {
    var statusResult: [FileStatus] = []
    var statusError: Error?
    var diffResult: String = ""
    var addResult: CommandResult = CommandResult(exitCode: 0, stdout: "", stderr: "", duration: 0, command: "chezmoi add")
    var addError: Error?
    var updateResult: CommandResult = CommandResult(exitCode: 0, stdout: "", stderr: "", duration: 0, command: "chezmoi update")
    var updateError: Error?

    /// Tracks paths passed to add().
    var addedPaths: [String] = []

    /// Tracks how many times status() was called.
    var statusCallCount = 0

    func status() async throws -> [FileStatus] {
        statusCallCount += 1
        if let error = statusError { throw error }
        return statusResult
    }

    func diff(for path: String) async throws -> String {
        return diffResult
    }

    func add(path: String) async throws -> CommandResult {
        addedPaths.append(path)
        if let error = addError { throw error }
        return addResult
    }

    func update() async throws -> CommandResult {
        if let error = updateError { throw error }
        return updateResult
    }

    var commitAndPushError: Error?
    var commitAndPushCallCount = 0

    func commitAndPush(message: String) async throws {
        commitAndPushCallCount += 1
        if let error = commitAndPushError { throw error }
    }
} // End of class MockChezmoiService

/// Mock implementation of GitServiceProtocol for testing.
final class MockGitService: GitServiceProtocol, @unchecked Sendable {
    var fetchResult: CommandResult = CommandResult(exitCode: 0, stdout: "", stderr: "", duration: 0, command: "git fetch")
    var fetchError: Error?
    var aheadBehindResult: (ahead: Int, behind: Int) = (ahead: 0, behind: 0)
    var aheadBehindError: Error?
    var remoteChangedFilesResult: Set<String> = []

    /// Tracks how many times fetch() was called.
    var fetchCallCount = 0

    func fetch() async throws -> CommandResult {
        fetchCallCount += 1
        if let error = fetchError { throw error }
        return fetchResult
    }

    func aheadBehind() async throws -> (ahead: Int, behind: Int) {
        if let error = aheadBehindError { throw error }
        return aheadBehindResult
    }

    func remoteChangedFiles() async throws -> Set<String> {
        return remoteChangedFilesResult
    }
} // End of class MockGitService

/// Mock implementation of FileStateEngineProtocol for testing.
final class MockFileStateEngine: FileStateEngineProtocol, @unchecked Sendable {
    var classifyResult: [FileStatus]?

    func classify(localFiles: [FileStatus], remoteBehind: Int) -> [FileStatus] {
        return classifyResult ?? localFiles
    }

    func classify(localFiles: [FileStatus], remoteBehind: Int, remoteChangedFiles: Set<String>) -> [FileStatus] {
        return classifyResult ?? localFiles
    }
} // End of class MockFileStateEngine

// MARK: - AppStateStore Tests

final class AppStateStoreTests: XCTestCase {

    private var mockChezmoi: MockChezmoiService!
    private var mockGit: MockGitService!
    private var mockEngine: MockFileStateEngine!

    override func setUp() {
        super.setUp()
        mockChezmoi = MockChezmoiService()
        mockGit = MockGitService()
        mockEngine = MockFileStateEngine()
    } // End of func setUp()

    /// Helper to create a fresh store on the main actor.
    @MainActor
    private func makeStore() -> AppStateStore {
        return AppStateStore(
            chezmoiService: mockChezmoi,
            gitService: mockGit,
            fileStateEngine: mockEngine
        )
    } // End of func makeStore()

    // MARK: - Refresh tests

    /// Tests that refresh updates the snapshot with data from mocked services.
    @MainActor
    func testRefreshUpdatesSnapshot() async {
        let files = [
            FileStatus(path: ".bashrc", state: .localDrift),
            FileStatus(path: ".zshrc", state: .remoteDrift)
        ]
        mockChezmoi.statusResult = [FileStatus(path: ".bashrc", state: .localDrift)]
        mockEngine.classifyResult = files

        let store = makeStore()
        await store.refresh()

        XCTAssertEqual(store.snapshot.files.count, 2)
        XCTAssertNotNil(store.snapshot.lastRefreshAt)
    } // End of func testRefreshUpdatesSnapshot()

    /// Tests that refreshState transitions from idle to success after refresh.
    @MainActor
    func testRefreshSetsRefreshStateCorrectly() async {
        mockChezmoi.statusResult = []

        let store = makeStore()
        XCTAssertTrue(isIdle(store.refreshState))

        await store.refresh()

        if case .success = store.refreshState {
            // Expected
        } else {
            XCTFail("Expected refreshState to be .success, got \(store.refreshState)")
        }
    } // End of func testRefreshSetsRefreshStateCorrectly()

    /// Tests that refresh handles errors by setting refreshState to .error.
    @MainActor
    func testRefreshHandlesErrors() async {
        mockChezmoi.statusError = AppError.unknown("test error")

        let store = makeStore()
        await store.refresh()

        if case .error = store.refreshState {
            // Expected
        } else {
            XCTFail("Expected refreshState to be .error, got \(store.refreshState)")
        }
    } // End of func testRefreshHandlesErrors()

    /// Tests that refresh logs an activity event on success.
    @MainActor
    func testRefreshLogsActivityEvent() async {
        mockChezmoi.statusResult = []

        let store = makeStore()
        await store.refresh()

        XCTAssertFalse(store.activityLog.isEmpty)
        XCTAssertEqual(store.activityLog.last?.eventType, .refresh)
    } // End of func testRefreshLogsActivityEvent()

    /// Tests that refresh logs an error event on failure.
    @MainActor
    func testRefreshLogsErrorEventOnFailure() async {
        mockChezmoi.statusError = AppError.unknown("fail")

        let store = makeStore()
        await store.refresh()

        XCTAssertFalse(store.activityLog.isEmpty)
        XCTAssertEqual(store.activityLog.last?.eventType, .error)
    } // End of func testRefreshLogsErrorEventOnFailure()

    // MARK: - Add tests

    /// Tests that addSingle calls chezmoi add with the correct path.
    @MainActor
    func testAddSingleCallsChezmoiAdd() async {
        mockChezmoi.statusResult = []

        let store = makeStore()
        await store.addSingle(path: ".bashrc")

        XCTAssertTrue(mockChezmoi.addedPaths.contains(".bashrc"))
    } // End of func testAddSingleCallsChezmoiAdd()

    /// Tests that addAllSafe only adds localDrift files and excludes dualDrift/error.
    @MainActor
    func testAddAllSafeOnlyAddsLocalDriftFiles() async {
        let files = [
            FileStatus(path: ".bashrc", state: .localDrift),
            FileStatus(path: ".zshrc", state: .dualDrift),
            FileStatus(path: ".vimrc", state: .error, errorMessage: "broken"),
            FileStatus(path: ".gitconfig", state: .localDrift),
            FileStatus(path: ".tmux.conf", state: .remoteDrift)
        ]

        let store = makeStore()
        // Set the snapshot directly for testing
        store.snapshot = SyncSnapshot(lastRefreshAt: Date(), files: files)
        // Reset status so refresh after add works
        mockChezmoi.statusResult = []

        await store.addAllSafe()

        // Should only have added .bashrc and .gitconfig
        XCTAssertEqual(mockChezmoi.addedPaths.sorted(), [".bashrc", ".gitconfig"])
    } // End of func testAddAllSafeOnlyAddsLocalDriftFiles()

    // MARK: - Activity log bounds

    /// Tests that the activity log is bounded to 500 events.
    @MainActor
    func testActivityLogIsBoundedTo500() async {
        let store = makeStore()
        mockChezmoi.statusResult = []

        // Manually fill the log past 500
        for i in 0..<505 {
            store.activityLog.append(ActivityEvent(
                eventType: .refresh,
                message: "Event \(i)"
            ))
        }

        // Trigger a refresh which will append and then cap
        await store.refresh()

        XCTAssertLessThanOrEqual(store.activityLog.count, 500)
    } // End of func testActivityLogIsBoundedTo500()

    // MARK: - Helpers

    /// Checks if a RefreshState is .idle.
    private func isIdle(_ state: RefreshState) -> Bool {
        if case .idle = state { return true }
        return false
    } // End of func isIdle(_:)
} // End of class AppStateStoreTests

// MARK: - RefreshCoordinator Tests

final class RefreshCoordinatorTests: XCTestCase {

    /// Tests that concurrent refresh requests are deduplicated.
    func testConcurrentRefreshRequestsAreDeduplicated() async {
        let coordinator = RefreshCoordinator(debounceInterval: 0)
        let counter = Counter()

        // Launch multiple concurrent refresh requests
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await coordinator.performIfIdle {
                        await counter.increment()
                        // Simulate work
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }
                }
            }
        } // End of task group for concurrent requests

        // Only one should have executed (others were rejected because one was running)
        let count = await counter.value
        XCTAssertEqual(count, 1, "Expected only 1 execution, got \(count)")
    } // End of func testConcurrentRefreshRequestsAreDeduplicated()

    /// Tests that the coordinator allows a new refresh after the previous one completes.
    func testAllowsRefreshAfterCompletion() async {
        let coordinator = RefreshCoordinator(debounceInterval: 0)
        let counter = Counter()

        await coordinator.performIfIdle {
            await counter.increment()
        }

        await coordinator.performIfIdle {
            await counter.increment()
        }

        let count = await counter.value
        XCTAssertEqual(count, 2)
    } // End of func testAllowsRefreshAfterCompletion()

    /// Tests that the debounce interval prevents rapid successive refreshes.
    func testDebounceRejectsRapidRequests() async {
        let coordinator = RefreshCoordinator(debounceInterval: 5.0) // 5 second debounce
        let counter = Counter()

        // First request should execute
        await coordinator.performIfIdle {
            await counter.increment()
        }

        // Second request should be rejected (within debounce window)
        await coordinator.performIfIdle {
            await counter.increment()
        }

        let count = await counter.value
        XCTAssertEqual(count, 1, "Expected 1 execution due to debounce, got \(count)")
    } // End of func testDebounceRejectsRapidRequests()

    /// Tests that cancel() resets the running state.
    func testCancelResetsRunningState() async {
        let coordinator = RefreshCoordinator()
        await coordinator.cancel()
        let running = await coordinator.isRunning
        XCTAssertFalse(running)
    } // End of func testCancelResetsRunningState()
} // End of class RefreshCoordinatorTests

// MARK: - PreferencesStore Tests

final class PreferencesStoreTests: XCTestCase {

    /// Creates a temporary directory and ConfigFileStore for test isolation.
    /// - Returns: A tuple of (ConfigFileStore, temp directory URL to clean up).
    private func makeTempConfigFileStore() -> (ConfigFileStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chezmoiTest-\(UUID().uuidString)", isDirectory: true)
        let store = ConfigFileStore(directory: tempDir)
        return (store, tempDir)
    } // End of func makeTempConfigFileStore()

    /// Tests that preferences round-trip through PreferencesStore.
    func testPreferencesRoundTrip() {
        let suiteName = "test.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let (configStore, tempDir) = makeTempConfigFileStore()
        let prefsStore = PreferencesStore(defaults: defaults, configFileStore: configStore)

        var prefs = AppPreferences.defaults
        prefs.pollIntervalMinutes = 10
        prefs.notificationsEnabled = false
        prefs.autoFetchEnabled = false
        prefs.preferredEditor = "vim"

        prefsStore.save(prefs)
        let loaded = prefsStore.load()

        XCTAssertEqual(loaded.pollIntervalMinutes, 10)
        XCTAssertEqual(loaded.notificationsEnabled, false)
        XCTAssertEqual(loaded.autoFetchEnabled, false)
        XCTAssertEqual(loaded.preferredEditor, "vim")

        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
    } // End of func testPreferencesRoundTrip()

    /// Tests that loading preferences returns defaults when nothing is saved.
    func testPreferencesDefaultsWhenEmpty() {
        let suiteName = "test.preferences.empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let (configStore, tempDir) = makeTempConfigFileStore()
        let prefsStore = PreferencesStore(defaults: defaults, configFileStore: configStore)

        let loaded = prefsStore.load()
        XCTAssertEqual(loaded, .defaults)

        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
    } // End of func testPreferencesDefaultsWhenEmpty()
} // End of class PreferencesStoreTests

// MARK: - ActivityLogStore Tests

final class ActivityLogStoreTests: XCTestCase {

    /// Tests saving and loading activity events.
    func testSaveAndLoadEvents() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activityLogTest.\(UUID().uuidString)")
        let logStore = ActivityLogStore(directoryURL: tempDir)

        let events = [
            ActivityEvent(eventType: .refresh, message: "Test refresh"),
            ActivityEvent(eventType: .add, message: "Test add", relatedFilePath: ".bashrc")
        ]

        try logStore.save(events: events)
        let loaded = try logStore.load()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].eventType, .refresh)
        XCTAssertEqual(loaded[1].message, "Test add")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    } // End of func testSaveAndLoadEvents()

    /// Tests that loading from a non-existent file returns an empty array.
    func testLoadReturnsEmptyWhenNoFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activityLogEmpty.\(UUID().uuidString)")
        let logStore = ActivityLogStore(directoryURL: tempDir)

        let loaded = try logStore.load()
        XCTAssertTrue(loaded.isEmpty)
    } // End of func testLoadReturnsEmptyWhenNoFile()

    /// Tests that save bounds events to 500.
    func testSaveBoundsEventsTo500() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("activityLogBounds.\(UUID().uuidString)")
        let logStore = ActivityLogStore(directoryURL: tempDir)

        let events = (0..<600).map { i in
            ActivityEvent(eventType: .refresh, message: "Event \(i)")
        }

        try logStore.save(events: events)
        let loaded = try logStore.load()

        XCTAssertEqual(loaded.count, 500)
        // Should keep the newest (last 500)
        XCTAssertEqual(loaded.first?.message, "Event 100")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    } // End of func testSaveBoundsEventsTo500()
} // End of class ActivityLogStoreTests

// MARK: - Thread-safe counter for testing

/// A thread-safe counter for use in concurrent test scenarios.
private actor Counter {
    var value: Int = 0

    /// Increments the counter by one.
    func increment() {
        value += 1
    }
} // End of actor Counter
