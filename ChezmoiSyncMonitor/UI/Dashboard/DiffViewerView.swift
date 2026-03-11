import SwiftUI

/// A sheet view for displaying the diff output of a chezmoi-managed file.
///
/// Shows the file path in a header, the diff text with syntax coloring
/// (green for additions, red for deletions, blue for hunk headers),
/// and a close button.
struct DiffViewerView: View {

    /// The file path being diffed.
    let filePath: String

    /// The raw diff text to display.
    let diffText: String

    /// Dismiss action for the sheet.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(Strings.diffViewer.title(filePath))
                    .font(.headline)

                Spacer()

                Button(Strings.navigation.close) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            } // End of header HStack
            .padding()

            Divider()

            // Diff content
            ScrollView([.horizontal, .vertical]) {
                Text(attributedDiff)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            } // End of ScrollView
            .background(Color(.textBackgroundColor))
        } // End of outer VStack
        .frame(minWidth: 600, minHeight: 400)
    } // End of body

    /// Builds an `AttributedString` from the diff text with syntax coloring.
    private var attributedDiff: AttributedString {
        var result = AttributedString()
        let lines = diffText.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            var attributed = AttributedString(line)
            if line.hasPrefix("+") {
                attributed.foregroundColor = .green
            } else if line.hasPrefix("-") {
                attributed.foregroundColor = .red
            } else if line.hasPrefix("@@") {
                attributed.foregroundColor = .blue
            }
            result.append(attributed)
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        } // End of for loop over diff lines
        return result
    } // End of computed property attributedDiff
} // End of struct DiffViewerView
