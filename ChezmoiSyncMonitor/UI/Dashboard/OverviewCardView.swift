import SwiftUI

/// A reusable card view displaying a count, label, and icon for a sync state category.
///
/// Used in the dashboard header to show aggregate counts of local drift,
/// remote drift, conflicts, and errors. Clicking a card filters the file list.
struct OverviewCardView: View {

    /// The SF Symbol icon name to display.
    let iconName: String

    /// The numeric count to display prominently.
    let count: Int

    /// The label text below the count.
    let label: String

    /// The accent color for the icon and background tint.
    let color: Color

    /// Whether this card is currently selected as a filter.
    let isSelected: Bool

    /// Action to invoke when the card is clicked.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } // End of VStack inside card button
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.15) : Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
        } // End of Button
        .buttonStyle(.plain)
    } // End of body
} // End of struct OverviewCardView
