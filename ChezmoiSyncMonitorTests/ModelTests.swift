import XCTest
@testable import ChezmoiSyncMonitor

/// Tests for the domain models, ensuring correct behavior of enums,
/// structs, and their computed properties.
final class ModelTests: XCTestCase {

    // MARK: - FileSyncState Ordering

    /// Verifies that FileSyncState cases are ordered by precedence.
    func testFileSyncStateOrdering() {
        XCTAssertTrue(FileSyncState.clean < FileSyncState.localDrift)
        XCTAssertTrue(FileSyncState.localDrift < FileSyncState.remoteDrift)
        XCTAssertTrue(FileSyncState.remoteDrift < FileSyncState.dualDrift)
        XCTAssertTrue(FileSyncState.dualDrift < FileSyncState.error)
        XCTAssertFalse(FileSyncState.error < FileSyncState.clean)
    } // End of func testFileSyncStateOrdering

    /// Verifies that equal states are not less than each other.
    func testFileSyncStateEqualityNotLessThan() {
        XCTAssertFalse(FileSyncState.clean < FileSyncState.clean)
        XCTAssertFalse(FileSyncState.error < FileSyncState.error)
    }

    /// Verifies that display names are non-empty for all states.
    func testFileSyncStateDisplayNames() {
        let allStates: [FileSyncState] = [.clean, .localDrift, .remoteDrift, .dualDrift, .error]
        for state in allStates {
            XCTAssertFalse(state.displayName.isEmpty, "\(state) should have a non-empty display name")
            XCTAssertFalse(state.iconName.isEmpty, "\(state) should have a non-empty icon name")
        }
    } // End of func testFileSyncStateDisplayNames

    // MARK: - SyncSnapshot.overallState

    /// Verifies that overallState returns clean for an empty snapshot.
    func testSyncSnapshotOverallStateEmpty() {
        let snapshot = SyncSnapshot.empty
        XCTAssertEqual(snapshot.overallState, .clean)
    }

    /// Verifies that overallState returns the worst state across all files.
    func testSyncSnapshotOverallStateWorstWins() {
        let files = [
            FileStatus(path: "a", state: .clean),
            FileStatus(path: "b", state: .localDrift),
            FileStatus(path: "c", state: .remoteDrift),
        ]
        let snapshot = SyncSnapshot(
            lastRefreshAt: Date(),
            files: files
        )
        XCTAssertEqual(snapshot.overallState, .remoteDrift)
    } // End of func testSyncSnapshotOverallStateWorstWins

    /// Verifies that overallState returns error when any file is in error state.
    func testSyncSnapshotOverallStateWithError() {
        let files = [
            FileStatus(path: "a", state: .clean),
            FileStatus(path: "b", state: .error, errorMessage: "something broke"),
        ]
        let snapshot = SyncSnapshot(
            lastRefreshAt: nil,
            files: files
        )
        XCTAssertEqual(snapshot.overallState, .error)
    } // End of func testSyncSnapshotOverallStateWithError

    // MARK: - AppPreferences Codable Round-Trip

    /// Verifies that AppPreferences can be encoded to JSON and decoded back.
    func testAppPreferencesCodableRoundTrip() throws {
        let prefs = AppPreferences(
            schemaVersion: 1,
            pollIntervalMinutes: 10,
            notificationsEnabled: false,
            batchSafeSyncEnabled: true,
            launchAtLogin: false,
            preferredMergeTool: "opendiff",
            preferredEditor: "code",
            chezmoiPathOverride: "/opt/bin/chezmoi",
            gitPathOverride: nil,
            sourceRepoPathOverride: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppPreferences.self, from: data)

        XCTAssertEqual(prefs, decoded)
    } // End of func testAppPreferencesCodableRoundTrip

    /// Verifies that default preferences round-trip correctly.
    func testAppPreferencesDefaultsRoundTrip() throws {
        let prefs = AppPreferences.defaults
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertEqual(prefs, decoded)
    }

    // MARK: - ActivityEvent Codable Round-Trip

    /// Verifies that ActivityEvent can be encoded to JSON and decoded back.
    func testActivityEventCodableRoundTrip() throws {
        let event = ActivityEvent(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            eventType: .refresh,
            message: "Refresh completed",
            relatedFilePath: "~/.zshrc"
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: data)

        XCTAssertEqual(event.id, decoded.id)
        XCTAssertEqual(event.timestamp, decoded.timestamp)
        XCTAssertEqual(event.eventType, decoded.eventType)
        XCTAssertEqual(event.message, decoded.message)
        XCTAssertEqual(event.relatedFilePath, decoded.relatedFilePath)
    } // End of func testActivityEventCodableRoundTrip

    /// Verifies that ActivityEvent with nil relatedFilePath round-trips.
    func testActivityEventCodableNilPath() throws {
        let event = ActivityEvent(
            eventType: .error,
            message: "Something failed"
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: data)

        XCTAssertEqual(event.id, decoded.id)
        XCTAssertNil(decoded.relatedFilePath)
    }

    // MARK: - AppError Descriptions

    /// Verifies that each AppError case produces a non-empty error description.
    func testAppErrorDescriptions() {
        let errors: [AppError] = [
            .cliFailure(command: "chezmoi status", exitCode: 1, stderr: "not found"),
            .authError("SSH key expired"),
            .repoUnreachable("https://example.com/repo.git"),
            .parseFailure("unexpected format"),
            .unknown("mystery"),
        ]

        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description, "\(error) should have an error description")
            XCTAssertFalse(description!.isEmpty, "\(error) should have a non-empty description")
        }
    } // End of func testAppErrorDescriptions

    /// Verifies that cliFailure includes the command name in the description.
    func testAppErrorCliFailureContainsCommand() {
        let error = AppError.cliFailure(command: "chezmoi diff", exitCode: 2, stderr: "bad path")
        let desc = error.errorDescription ?? ""
        XCTAssertTrue(desc.contains("chezmoi diff"), "Description should contain the command name")
    }

    // MARK: - CommandResult.isSuccess

    /// Verifies that isSuccess returns true for exit code 0.
    func testCommandResultIsSuccessTrue() {
        let result = CommandResult(
            exitCode: 0,
            stdout: "ok",
            stderr: "",
            duration: 0.5,
            command: "chezmoi status"
        )
        XCTAssertTrue(result.isSuccess)
    }

    /// Verifies that isSuccess returns false for non-zero exit codes.
    func testCommandResultIsSuccessFalse() {
        let result = CommandResult(
            exitCode: 1,
            stdout: "",
            stderr: "error",
            duration: 0.1,
            command: "chezmoi add"
        )
        XCTAssertFalse(result.isSuccess)
    }

    /// Verifies that isSuccess returns false for negative exit codes.
    func testCommandResultIsSuccessNegative() {
        let result = CommandResult(
            exitCode: -1,
            stdout: "",
            stderr: "signal",
            duration: 0.0,
            command: "git fetch"
        )
        XCTAssertFalse(result.isSuccess)
    }
} // End of class ModelTests
