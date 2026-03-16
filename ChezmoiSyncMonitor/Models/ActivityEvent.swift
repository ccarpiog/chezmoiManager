import Foundation

/// Categorizes the type of activity that occurred.
enum EventType: String, Codable, Sendable {
    case refresh
    case add
    case update
    case warning
    case error
    case notification
} // End of enum EventType

/// A timestamped record of an action or event within the application.
///
/// Used to populate the activity log in the dashboard and for diagnostics.
struct ActivityEvent: Identifiable, Codable, Sendable {
    /// Unique identifier for this event.
    let id: UUID

    /// When the event occurred.
    let timestamp: Date

    /// The category of the event.
    let eventType: EventType

    /// A human-readable description of what happened.
    let message: String

    /// The file path related to this event, if applicable.
    let relatedFilePath: String?

    /// Creates a new ActivityEvent.
    /// - Parameters:
    ///   - id: A unique identifier (defaults to a new UUID).
    ///   - timestamp: When the event occurred (defaults to now).
    ///   - eventType: The category of the event.
    ///   - message: A human-readable description.
    ///   - relatedFilePath: An optional related file path.
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: EventType,
        message: String,
        relatedFilePath: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.message = message
        self.relatedFilePath = relatedFilePath
    } // End of init
} // End of struct ActivityEvent
