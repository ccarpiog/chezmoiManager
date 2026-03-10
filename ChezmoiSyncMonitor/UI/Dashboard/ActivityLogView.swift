import SwiftUI

/// A collapsible panel displaying recent activity events in reverse chronological order.
///
/// Each row shows a timestamp (HH:mm:ss), an event type icon, and a description message.
struct ActivityLogView: View {

    /// The list of activity events to display.
    let events: [ActivityEvent]

    /// Whether the log panel is expanded.
    @State private var isExpanded = true

    /// Date formatter for displaying event timestamps.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text("Activity Log")
                        .font(.headline)

                    Text("(\(events.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                } // End of header HStack
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            } // End of header Button
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                if events.isEmpty {
                    Text("No activity recorded yet.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ScrollView {
                        Text(attributedLog)
                            .font(.system(.callout, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .textSelection(.enabled)
                    } // End of ScrollView
                    .frame(maxHeight: 150)
                } // End of else (events not empty)
            } // End of if isExpanded
        } // End of outer VStack
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } // End of body

    /// Builds a single `AttributedString` from all events for cross-row text selection.
    private var attributedLog: AttributedString {
        var result = AttributedString()
        let reversed = events.reversed()
        for (index, event) in reversed.enumerated() {
            var prefix = AttributedString("\(iconEmoji(for: event.eventType)) ")
            prefix.foregroundColor = iconColor(for: event.eventType)
            result.append(prefix)

            let line = AttributedString(
                "\(Self.timeFormatter.string(from: event.timestamp))  \(event.message)"
            )
            result.append(line)

            if index < reversed.count - 1 {
                result.append(AttributedString("\n"))
            }
        } // End of for loop over events
        return result
    } // End of computed property attributedLog

    /// Returns a text emoji/symbol for a given event type (used in the attributed string).
    /// - Parameter eventType: The event type.
    /// - Returns: A Unicode symbol string.
    private func iconEmoji(for eventType: EventType) -> String {
        switch eventType {
        case .refresh: return "↻"
        case .add: return "⊕"
        case .update: return "↓"
        case .error: return "⊘"
        case .notification: return "♪"
        }
    } // End of func iconEmoji(for:)

    /// Returns the SF Symbol name for a given event type.
    /// - Parameter eventType: The event type to get an icon for.
    /// - Returns: An SF Symbol name string.
    private func iconName(for eventType: EventType) -> String {
        switch eventType {
        case .refresh:
            return "arrow.clockwise"
        case .add:
            return "plus.circle"
        case .update:
            return "arrow.down.circle"
        case .error:
            return "xmark.circle"
        case .notification:
            return "bell"
        }
    } // End of func iconName(for:)

    /// Returns the color for a given event type icon.
    /// - Parameter eventType: The event type to get a color for.
    /// - Returns: A SwiftUI Color.
    private func iconColor(for eventType: EventType) -> Color {
        switch eventType {
        case .refresh:
            return .blue
        case .add:
            return .green
        case .update:
            return .orange
        case .error:
            return .red
        case .notification:
            return .purple
        }
    } // End of func iconColor(for:)
} // End of struct ActivityLogView
