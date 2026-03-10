import XCTest
@testable import ChezmoiSyncMonitor

/// Tests for release hardening: RelativeTimeFormatter, StatusIconProvider,
/// and FileStateEngine.normalizeSourcePath edge cases.
final class HardeningTests: XCTestCase {

    // MARK: - RelativeTimeFormatter

    /// "just now" for dates less than 5 seconds ago.
    func testRelativeTimeJustNow() {
        let date = Date().addingTimeInterval(-2)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "just now")
    }

    /// "just now" for future dates.
    func testRelativeTimeFutureDate() {
        let date = Date().addingTimeInterval(10)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "just now")
    }

    /// Seconds ago (between 5 and 59 seconds).
    func testRelativeTimeSeconds() {
        let date = Date().addingTimeInterval(-30)
        let result = RelativeTimeFormatter.string(for: date)
        XCTAssertTrue(result.hasSuffix("sec ago"), "Expected seconds format, got: \(result)")
    }

    /// Exactly 1 minute ago.
    func testRelativeTimeOneMinute() {
        let date = Date().addingTimeInterval(-60)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "1 min ago")
    }

    /// Multiple minutes ago (e.g., 15 minutes).
    func testRelativeTimeMinutes() {
        let date = Date().addingTimeInterval(-15 * 60)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "15 min ago")
    }

    /// Exactly 1 hour ago.
    func testRelativeTimeOneHour() {
        let date = Date().addingTimeInterval(-3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "1 hour ago")
    }

    /// Multiple hours ago (e.g., 5 hours).
    func testRelativeTimeHours() {
        let date = Date().addingTimeInterval(-5 * 3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "5 hours ago")
    }

    /// Exactly 1 day ago.
    func testRelativeTimeOneDay() {
        let date = Date().addingTimeInterval(-24 * 3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "1 day ago")
    }

    /// Multiple days ago (e.g., 3 days).
    func testRelativeTimeDays() {
        let date = Date().addingTimeInterval(-3 * 24 * 3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "3 days ago")
    }

    /// Large interval (e.g., 30 days).
    func testRelativeTimeLargeInterval() {
        let date = Date().addingTimeInterval(-30 * 24 * 3600)
        XCTAssertEqual(RelativeTimeFormatter.string(for: date), "30 days ago")
    }

    // MARK: - StatusIconProvider

    /// Running refresh returns a valid icon with primary color.
    func testStatusIconRunning() {
        let config = StatusIconProvider.icon(for: .clean, refreshState: .running)
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .primary)
    }

    /// Clean state returns a valid icon with gray color.
    func testStatusIconClean() {
        let config = StatusIconProvider.icon(for: .clean, refreshState: .idle)
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .gray)
    }

    /// Local drift returns a valid icon with blue color.
    func testStatusIconLocalDrift() {
        let config = StatusIconProvider.icon(for: .localDrift, refreshState: .success(Date()))
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .blue)
    }

    /// Remote drift returns a valid icon with orange color.
    func testStatusIconRemoteDrift() {
        let config = StatusIconProvider.icon(for: .remoteDrift, refreshState: .idle)
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .orange)
    }

    /// Dual drift returns a valid icon with red color.
    func testStatusIconDualDrift() {
        let config = StatusIconProvider.icon(for: .dualDrift, refreshState: .idle)
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .red)
    }

    /// Error state returns a valid icon with red color.
    func testStatusIconError() {
        let config = StatusIconProvider.icon(for: .error, refreshState: .idle)
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .red)
    }

    /// Running state takes priority over error state.
    func testStatusIconRunningOverridesError() {
        let config = StatusIconProvider.icon(for: .error, refreshState: .running)
        XCTAssertEqual(config.color, .primary)
    }

    /// Offline state returns secondary color.
    func testStatusIconOffline() {
        let config = StatusIconProvider.icon(for: .clean, refreshState: .idle, isOnline: false)
        XCTAssertTrue(config.image.isTemplate)
        XCTAssertEqual(config.color, .secondary)
    }

    // MARK: - FileStateEngine.normalizeSourcePath edge cases

    /// Plain filename without any chezmoi prefixes passes through unchanged.
    func testNormalizeSourcePathPlainFile() {
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("Makefile"), "Makefile")
    }

    /// Empty string returns empty string.
    func testNormalizeSourcePathEmpty() {
        XCTAssertEqual(FileStateEngine.normalizeSourcePath(""), "")
    }

    /// Multiple stacked prefixes (e.g., private_readonly_dot_).
    func testNormalizeSourcePathStackedPrefixes() {
        XCTAssertEqual(
            FileStateEngine.normalizeSourcePath("private_readonly_dot_secret"),
            ".secret"
        )
    }

    /// exact_ prefix with nested path.
    func testNormalizeSourcePathExactPrefix() {
        XCTAssertEqual(
            FileStateEngine.normalizeSourcePath("exact_dot_config/exact_systemd"),
            ".config/systemd"
        )
    }

    /// empty_ prefix.
    func testNormalizeSourcePathEmptyPrefix() {
        XCTAssertEqual(
            FileStateEngine.normalizeSourcePath("empty_dot_keep"),
            ".keep"
        )
    }

    /// executable_ prefix with .tmpl suffix.
    func testNormalizeSourcePathExecutableTmpl() {
        XCTAssertEqual(
            FileStateEngine.normalizeSourcePath("executable_dot_local/bin/my-script.sh.tmpl"),
            ".local/bin/my-script.sh"
        )
    }

    /// Path component that only has "dot_" (becomes just ".").
    func testNormalizeSourcePathDotOnly() {
        XCTAssertEqual(FileStateEngine.normalizeSourcePath("dot_"), ".")
    }

    /// Deeply nested path with mixed prefixes.
    func testNormalizeSourcePathDeepNested() {
        XCTAssertEqual(
            FileStateEngine.normalizeSourcePath("private_dot_config/nvim/lua/plugins/init.lua.tmpl"),
            ".config/nvim/lua/plugins/init.lua"
        )
    }

    /// File that starts with "dot_" in a subdirectory.
    func testNormalizeSourcePathDotInSubdir() {
        XCTAssertEqual(
            FileStateEngine.normalizeSourcePath("dot_config/dot_hidden/file"),
            ".config/.hidden/file"
        )
    }
} // End of class HardeningTests
