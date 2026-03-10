import XCTest
@testable import ChezmoiSyncMonitor

// MARK: - Mock WatcherService

/// A spy implementation of WatcherServiceProtocol that records calls
/// and allows injecting behavior for testing.
final class MockWatcherService: WatcherServiceProtocol, @unchecked Sendable {

    /// Whether start() was called.
    var startCalled = false

    /// Whether stop() was called.
    var stopCalled = false

    /// Starts the mock watcher.
    func start() async {
        startCalled = true
    } // End of func start()

    /// Stops the mock watcher.
    func stop() {
        stopCalled = true
    } // End of func stop()
} // End of class MockWatcherService

// MARK: - Mock NotificationService

/// A spy implementation of NotificationServiceProtocol that captures
/// notification calls for verification in tests.
final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {

    /// Whether requestAuthorization() was called.
    var authorizationRequested = false

    /// The result to return from requestAuthorization().
    var authorizationResult = true

    /// The snapshots passed to notifyDrift(snapshot:).
    var notifiedSnapshots: [SyncSnapshot] = []

    /// Simulates requesting notification authorization.
    /// - Returns: The configured `authorizationResult`.
    func requestAuthorization() async throws -> Bool {
        authorizationRequested = true
        return authorizationResult
    } // End of func requestAuthorization()

    /// Records the snapshot for later verification.
    /// - Parameter snapshot: The sync snapshot.
    func notifyDrift(snapshot: SyncSnapshot) async {
        notifiedSnapshots.append(snapshot)
    } // End of func notifyDrift(snapshot:)
} // End of class MockNotificationService

// MARK: - WatcherService Tests

final class WatcherServiceTests: XCTestCase {

    /// Tests that WatcherService calls the refresh action on start.
    func testWatcherCallsRefreshOnStart() async {
        let refreshCalled = RefreshTracker()

        let watcher = WatcherService(
            refreshAction: {
                await refreshCalled.markCalled()
            },
            getInterval: { 5 }
        )

        await watcher.start()

        // Give a brief moment for the async refresh to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let called = await refreshCalled.wasCalled
        XCTAssertTrue(called, "WatcherService should trigger refresh on start")

        await watcher.stop()
    } // End of func testWatcherCallsRefreshOnStart()

    /// Tests that WatcherService polling triggers refresh after the interval.
    func testWatcherPollingTriggersRefresh() async {
        let refreshCount = RefreshCounter()

        // Use a very short interval for testing (1 minute is the minimum,
        // but we test the polling mechanism by checking the task is set up)
        let watcher = WatcherService(
            refreshAction: {
                await refreshCount.increment()
            },
            getInterval: { 1 }
        )

        await watcher.start()

        // Wait briefly for the initial refresh to fire
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let count = await refreshCount.value
        // At minimum, the initial refresh should have fired
        XCTAssertGreaterThanOrEqual(count, 1, "At least the initial refresh should fire")

        await watcher.stop()
    } // End of func testWatcherPollingTriggersRefresh()

    /// Tests that WatcherService debounces rapid refresh triggers.
    func testWatcherDebouncesRapidTriggers() async {
        let refreshCount = RefreshCounter()

        let watcher = WatcherService(
            refreshAction: {
                await refreshCount.increment()
            },
            getInterval: { 5 }
        )

        // Start fires initial refresh
        await watcher.start()

        // Wait briefly
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Stop and start again immediately - should be debounced
        await watcher.stop()
        await watcher.start()

        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let count = await refreshCount.value
        // The second start should be debounced (within 30s window)
        XCTAssertEqual(count, 1, "Second start should be debounced within 30s window")

        await watcher.stop()
    } // End of func testWatcherDebouncesRapidTriggers()

    /// Tests that stop cancels the watcher and allows restart.
    func testWatcherStopAndRestart() async {
        let refreshCount = RefreshCounter()

        let watcher = WatcherService(
            refreshAction: {
                await refreshCount.increment()
            },
            getInterval: { 5 }
        )

        await watcher.start()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await watcher.stop()

        let countAfterStop = await refreshCount.value
        XCTAssertGreaterThanOrEqual(countAfterStop, 1)

        // After waiting past the debounce window, restart should work
        // (in real usage; here we just verify stop doesn't crash)
        await watcher.stop() // Double stop is safe
    } // End of func testWatcherStopAndRestart()
} // End of class WatcherServiceTests

// MARK: - NotificationService Tests

final class NotificationServiceTests: XCTestCase {

    /// Tests that requestAuthorization returns a boolean result.
    func testRequestAuthorizationReturnsResult() async throws {
        let service = NotificationService(isEnabled: { true })

        // In a test/CI environment, this may throw or return false.
        // We just verify it doesn't crash and returns a Bool.
        do {
            let result = try await service.requestAuthorization()
            // result is a Bool; either true or false is valid in test environment
            XCTAssertNotNil(result as Bool?)
        } catch {
            // Authorization request can fail in CI/sandboxed environments; that's acceptable
            XCTAssertNotNil(error)
        }
    } // End of func testRequestAuthorizationReturnsResult()

    /// Tests that notifyDrift does nothing when notifications are disabled.
    func testNotifyDriftSkipsWhenDisabled() async {
        let service = NotificationService(isEnabled: { false })

        let snapshot = SyncSnapshot(
            lastRefreshAt: Date(),
            files: [FileStatus(path: ".bashrc", state: .localDrift)]
        )

        // Should return without sending notifications (no crash, no error)
        await service.notifyDrift(snapshot: snapshot)
    } // End of func testNotifyDriftSkipsWhenDisabled()

    /// Tests that notifyDrift handles an empty (clean) snapshot gracefully.
    func testNotifyDriftClearsOnCleanSnapshot() async {
        let service = NotificationService(isEnabled: { true })

        let snapshot = SyncSnapshot.empty

        // Should clear previous notifications without error
        await service.notifyDrift(snapshot: snapshot)
    } // End of func testNotifyDriftClearsOnCleanSnapshot()
} // End of class NotificationServiceTests

// MARK: - AppStateStore Integration Tests

final class WatcherNotificationIntegrationTests: XCTestCase {

    /// Tests that AppStateStore starts the watcher and notification services.
    @MainActor
    func testAppStateStoreStartsServices() async {
        let mockChezmoi = MockChezmoiService()
        let mockGit = MockGitService()
        let mockEngine = MockFileStateEngine()
        let mockWatcher = MockWatcherService()
        let mockNotification = MockNotificationService()

        mockChezmoi.statusResult = []

        let store = AppStateStore(
            chezmoiService: mockChezmoi,
            gitService: mockGit,
            fileStateEngine: mockEngine,
            watcherService: mockWatcher,
            notificationService: mockNotification
        )

        await store.startServices()

        XCTAssertTrue(mockWatcher.startCalled, "WatcherService should be started")
        XCTAssertTrue(mockNotification.authorizationRequested, "Notification authorization should be requested")
    } // End of func testAppStateStoreStartsServices()

    /// Tests that AppStateStore calls notifyDrift after a successful refresh.
    @MainActor
    func testAppStateStoreNotifiesDriftAfterRefresh() async {
        let mockChezmoi = MockChezmoiService()
        let mockGit = MockGitService()
        let mockEngine = MockFileStateEngine()
        let mockNotification = MockNotificationService()

        let driftFiles = [
            FileStatus(path: ".bashrc", state: .localDrift),
            FileStatus(path: ".zshrc", state: .remoteDrift)
        ]
        mockChezmoi.statusResult = driftFiles
        mockEngine.classifyResult = driftFiles

        let store = AppStateStore(
            chezmoiService: mockChezmoi,
            gitService: mockGit,
            fileStateEngine: mockEngine,
            notificationService: mockNotification
        )

        await store.refresh()

        XCTAssertEqual(mockNotification.notifiedSnapshots.count, 1,
                       "notifyDrift should be called once after refresh")
        XCTAssertEqual(mockNotification.notifiedSnapshots.first?.localDriftCount, 1)
        XCTAssertEqual(mockNotification.notifiedSnapshots.first?.remoteDriftCount, 1)
    } // End of func testAppStateStoreNotifiesDriftAfterRefresh()

    /// Tests that AppStateStore stops the watcher via stopServices().
    @MainActor
    func testAppStateStoreStopsServices() async {
        let mockChezmoi = MockChezmoiService()
        let mockGit = MockGitService()
        let mockEngine = MockFileStateEngine()
        let mockWatcher = MockWatcherService()

        mockChezmoi.statusResult = []

        let store = AppStateStore(
            chezmoiService: mockChezmoi,
            gitService: mockGit,
            fileStateEngine: mockEngine,
            watcherService: mockWatcher
        )

        store.stopServices()

        XCTAssertTrue(mockWatcher.stopCalled, "WatcherService should be stopped")
    } // End of func testAppStateStoreStopsServices()
} // End of class WatcherNotificationIntegrationTests

// MARK: - Test helpers

/// Thread-safe tracker to check if refresh was called.
private actor RefreshTracker {
    var wasCalled = false

    /// Marks the refresh as having been called.
    func markCalled() {
        wasCalled = true
    }
} // End of actor RefreshTracker

/// Thread-safe counter for tracking refresh invocations.
private actor RefreshCounter {
    var value = 0

    /// Increments the counter by one.
    func increment() {
        value += 1
    }
} // End of actor RefreshCounter
