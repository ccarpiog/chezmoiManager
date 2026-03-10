import AppKit
import Foundation
import Network
import os

/// Background watcher that triggers refresh from multiple sources:
/// polling timer, wake-from-sleep, and network connectivity changes.
///
/// Uses `OSAllocatedUnfairLock` for thread-safe mutable state access,
/// conforming to both `Sendable` and the nonisolated requirements of
/// `WatcherServiceProtocol`.
final class WatcherService: WatcherServiceProtocol, @unchecked Sendable {

    /// The closure to call when a refresh should be triggered.
    private let refreshAction: @Sendable () async -> Void

    /// A closure that returns the current poll interval in minutes.
    private let getInterval: @Sendable () -> Int

    /// Optional closure called when network connectivity changes.
    /// The boolean parameter is `true` when online, `false` when offline.
    private let onConnectivityChange: (@Sendable (Bool) -> Void)?

    /// The minimum number of seconds between consecutive refresh triggers.
    static let debounceSeconds: TimeInterval = 30

    /// Thread-safe mutable state container.
    private struct State: @unchecked Sendable {
        var lastRefreshTime: Date?
        var pollingTask: Task<Void, Never>?
        var wakeObserver: (any NSObjectProtocol)?
        var pathMonitor: NWPathMonitor?
        var isRunning = false
        var wasOnline: Bool?
    } // End of struct State

    /// Lock-protected mutable state.
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Creates a new WatcherService.
    /// - Parameters:
    ///   - refreshAction: The async closure to invoke when a refresh is needed.
    ///   - getInterval: A closure returning the current poll interval in minutes.
    ///   - onConnectivityChange: Optional closure called when network reachability changes.
    init(
        refreshAction: @escaping @Sendable () async -> Void,
        getInterval: @escaping @Sendable () -> Int,
        onConnectivityChange: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.refreshAction = refreshAction
        self.getInterval = getInterval
        self.onConnectivityChange = onConnectivityChange
    } // End of init(refreshAction:getInterval:onConnectivityChange:)

    /// Starts all watchers: initial refresh, polling timer, wake observer, and network monitor.
    func start() async {
        let alreadyRunning = state.withLock { s -> Bool in
            if s.isRunning { return true }
            s.isRunning = true
            return false
        }
        guard !alreadyRunning else { return }

        // Trigger an initial refresh on launch
        await triggerRefreshIfAllowed()

        // Check if stop() was called during the initial refresh
        let stillRunning = state.withLock { $0.isRunning }
        guard stillRunning else { return }

        startPolling()
        startWakeObserver()
        startNetworkMonitor()
    } // End of func start()

    /// Stops all watchers and releases resources.
    func stop() {
        let (observer, monitor, task) = state.withLockUnchecked { s -> ((any NSObjectProtocol)?, NWPathMonitor?, Task<Void, Never>?) in
            s.isRunning = false
            let obs = s.wakeObserver
            let mon = s.pathMonitor
            let t = s.pollingTask
            s.wakeObserver = nil
            s.pathMonitor = nil
            s.pollingTask = nil
            return (obs, mon, t)
        }

        task?.cancel()

        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        monitor?.cancel()
    } // End of func stop()

    // MARK: - Debounce

    /// Triggers a refresh only if enough time has elapsed since the last one.
    /// This prevents multiple sources (wake + network) from firing simultaneously.
    private func triggerRefreshIfAllowed() async {
        let now = Date()
        let shouldRefresh = state.withLock { s -> Bool in
            if let lastTime = s.lastRefreshTime {
                let elapsed = now.timeIntervalSince(lastTime)
                if elapsed < WatcherService.debounceSeconds {
                    return false
                }
            }
            s.lastRefreshTime = now
            return true
        }

        guard shouldRefresh else { return }
        await refreshAction()
    } // End of func triggerRefreshIfAllowed()

    // MARK: - Polling

    /// Starts the periodic polling task using Task.sleep.
    private func startPolling() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                let intervalMinutes = self?.getInterval() ?? 5
                let clampedMinutes = max(1, min(60, intervalMinutes))
                let sleepNanos = UInt64(clampedMinutes) * 60 * 1_000_000_000

                do {
                    try await Task.sleep(nanoseconds: sleepNanos)
                } catch {
                    break // Task was cancelled
                }

                guard !Task.isCancelled else { break }
                await self?.triggerRefreshIfAllowed()
            } // End of polling while loop
        }

        state.withLock { s in
            s.pollingTask?.cancel()
            s.pollingTask = task
        }
    } // End of func startPolling()

    // MARK: - Wake from sleep

    /// Subscribes to NSWorkspace.didWakeNotification to trigger refresh after wake.
    private func startWakeObserver() {
        let refreshAction = self.refreshAction
        let stateRef = self.state

        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.triggerRefreshIfAllowed()
            }
        }

        nonisolated(unsafe) let unsafeObserver = observer
        state.withLock { s in
            s.wakeObserver = unsafeObserver
        }
    } // End of func startWakeObserver()

    // MARK: - Network change

    /// Starts an NWPathMonitor to detect network connectivity changes.
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()

        // Track whether we have received the initial status update
        let firstUpdateFlag = AtomicBoolFlag()

        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied

            // Report connectivity state change to the UI
            self?.onConnectivityChange?(isOnline)

            // Skip the initial status report that fires immediately on start
            if firstUpdateFlag.getAndSetFalseIfTrue() {
                self?.state.withLock { s in s.wasOnline = isOnline }
                return
            }

            // Edge-triggered refresh: only refresh on offline→online transition
            let wasOnline = self?.state.withLock { s -> Bool? in
                let prev = s.wasOnline
                s.wasOnline = isOnline
                return prev
            }

            if isOnline && wasOnline == false {
                Task { [weak self] in
                    await self?.triggerRefreshIfAllowed()
                }
            }
        }

        monitor.start(queue: DispatchQueue(label: "cc.carpio.ChezmoiSyncMonitor.networkMonitor"))

        state.withLock { s in
            s.pathMonitor = monitor
        }
    } // End of func startNetworkMonitor()
} // End of class WatcherService

// MARK: - AtomicBoolFlag

/// A simple thread-safe boolean flag for one-time state tracking.
private final class AtomicBoolFlag: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: true)

    /// Returns the current value and sets it to false if it was true.
    /// - Returns: `true` if this is the first call (flag was true).
    func getAndSetFalseIfTrue() -> Bool {
        return storage.withLock { value in
            if value {
                value = false
                return true
            }
            return false
        }
    } // End of func getAndSetFalseIfTrue()
} // End of class AtomicBoolFlag
