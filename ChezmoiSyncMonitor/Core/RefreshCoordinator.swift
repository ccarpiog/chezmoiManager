import Foundation

/// Actor that prevents overlapping refresh operations.
///
/// Provides single-flight execution, debouncing for regular refreshes,
/// one-slot force-refresh queueing, and cancellation support.
actor RefreshCoordinator {

    /// Whether a refresh operation is currently in progress.
    private(set) var isRunning: Bool = false

    /// The timestamp of the last completed refresh.
    private var lastCompletionTime: Date?

    /// The current in-flight task, if any.
    private var currentTask: Task<Void, Never>?

    /// Latest force-refresh work requested while a refresh was already running.
    ///
    /// One-slot queue: additional force requests while running replace the
    /// previous pending work so we execute at most one follow-up run.
    private var pendingForcedWork: (@Sendable () async -> Void)?

    /// The debounce interval in seconds.
    private let debounceInterval: TimeInterval

    /// Creates a new RefreshCoordinator.
    /// - Parameter debounceInterval: Minimum seconds between refresh completions. Defaults to 2.
    init(debounceInterval: TimeInterval = 2.0) {
        self.debounceInterval = debounceInterval
    } // End of init(debounceInterval:)

    /// Executes the given work closure if no refresh is currently running
    /// and the debounce interval has elapsed since the last completion.
    ///
    /// If a refresh is already in progress or the debounce window has not
    /// elapsed, the request is silently dropped (not queued).
    ///
    /// - Parameter work: The async work to perform.
    func performIfIdle(_ work: @Sendable @escaping () async -> Void) async {
        // Single-flight: ignore if already running
        guard !isRunning else { return }

        // Debounce: ignore if too soon after last completion
        if let lastTime = lastCompletionTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < debounceInterval {
                return
            }
        }

        isRunning = true

        let task = Task {
            await work()
        }
        currentTask = task

        // Wait for completion
        await task.value

        isRunning = false
        lastCompletionTime = Date()
        currentTask = nil

        // Honor one queued force-refresh request after current run completes.
        if let queuedWork = pendingForcedWork {
            pendingForcedWork = nil
            await forcePerform(queuedWork)
        }
    } // End of func performIfIdle(_:)

    /// Executes the given work closure, bypassing debounce but still respecting single-flight.
    ///
    /// Use this after mutations (add, update) to ensure the UI refreshes immediately.
    ///
    /// - Parameter work: The async work to perform.
    func forcePerform(_ work: @Sendable @escaping () async -> Void) async {
        // Do not drop force requests while running; queue one follow-up run.
        guard !isRunning else {
            pendingForcedWork = work
            return
        }
        isRunning = true
        let task = Task { await work() }
        currentTask = task
        await task.value
        isRunning = false
        lastCompletionTime = Date()
        currentTask = nil

        // Coalesce any additional force requests into one immediate follow-up run.
        if let queuedWork = pendingForcedWork {
            pendingForcedWork = nil
            await forcePerform(queuedWork)
        }
    } // End of func forcePerform(_:)

    /// Cancels any in-progress refresh operation.
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        pendingForcedWork = nil
    } // End of func cancel()
} // End of actor RefreshCoordinator
