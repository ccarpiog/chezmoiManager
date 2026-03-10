import Foundation

/// Persists activity events to a JSON file on disk.
///
/// Events are stored in `~/Library/Application Support/cc.carpio.ChezmoiSyncMonitor/activity.json`.
/// Retention is bounded to the last 500 events; older events are dropped on save.
struct ActivityLogStore: Sendable {

    /// Maximum number of events to retain.
    static let maxEvents = 500

    /// The directory where the activity log file is stored.
    private let directoryURL: URL

    /// The full path to the activity log JSON file.
    private var fileURL: URL {
        directoryURL.appendingPathComponent("activity.json")
    }

    /// Creates a new ActivityLogStore.
    /// - Parameter directoryURL: Override for the storage directory. Defaults to the app's
    ///   Application Support directory.
    init(directoryURL: URL? = nil) {
        if let url = directoryURL {
            self.directoryURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directoryURL = appSupport.appendingPathComponent("cc.carpio.ChezmoiSyncMonitor")
        }
    } // End of init(directoryURL:)

    /// Saves the given events to disk, retaining at most 500 events (newest kept).
    ///
    /// Creates the storage directory if it does not exist.
    ///
    /// - Parameter events: The events to persist.
    /// - Throws: If directory creation or file writing fails.
    func save(events: [ActivityEvent]) throws {
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Bound to last maxEvents
        let bounded: [ActivityEvent]
        if events.count > ActivityLogStore.maxEvents {
            bounded = Array(events.suffix(ActivityLogStore.maxEvents))
        } else {
            bounded = events
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bounded)
        try data.write(to: fileURL, options: .atomic)
    } // End of func save(events:)

    /// Loads previously saved events from disk.
    ///
    /// Returns an empty array if the file does not exist.
    ///
    /// - Returns: An array of persisted activity events.
    /// - Throws: If the file exists but cannot be decoded.
    func load() throws -> [ActivityEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ActivityEvent].self, from: data)
    } // End of func load()
} // End of struct ActivityLogStore
