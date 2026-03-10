import Foundation

/// Implementation of `GitServiceProtocol` that wraps git CLI commands.
///
/// Operates on the chezmoi source directory, which is determined by
/// running `chezmoi source-path`.
final class GitService: GitServiceProtocol, Sendable {

    /// The resolved path to the git executable.
    private let gitBinary: String

    /// The resolved path to the chezmoi executable (needed for source-path lookup).
    private let chezmoiBinary: String

    /// Creates a new GitService.
    ///
    /// - Parameters:
    ///   - gitPath: An optional explicit path to the git binary.
    ///   - chezmoiPath: An optional explicit path to the chezmoi binary.
    /// - Throws: `AppError.unknown` if either binary cannot be found.
    init(gitPath: String? = nil, chezmoiPath: String? = nil) throws {
        if let path = gitPath {
            self.gitBinary = path
        } else {
            guard let resolved = PATHResolver.gitPath() else {
                throw AppError.unknown("git binary not found in PATH")
            }
            self.gitBinary = resolved
        }

        if let path = chezmoiPath {
            self.chezmoiBinary = path
        } else {
            guard let resolved = PATHResolver.chezmoiPath() else {
                throw AppError.unknown("chezmoi binary not found in PATH")
            }
            self.chezmoiBinary = resolved
        }
    } // End of init(gitPath:chezmoiPath:)

    /// Resolves the chezmoi source directory by running `chezmoi source-path`.
    ///
    /// - Returns: The absolute path to the chezmoi source directory.
    /// - Throws: `AppError` if the command fails or returns empty output.
    private func sourceDirectory() async throws -> String {
        let result = try await ProcessRunner.run(
            command: chezmoiBinary,
            arguments: ["source-path"]
        )
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw AppError.parseFailure("chezmoi source-path returned empty output")
        }
        return path
    } // End of func sourceDirectory()

    /// Fetches the latest refs from the remote repository.
    ///
    /// - Returns: The `CommandResult` of the fetch command.
    /// - Throws: `AppError` if the git command fails.
    func fetch() async throws -> CommandResult {
        let sourceDir = try await sourceDirectory()
        return try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "fetch"]
        )
    } // End of func fetch()

    /// Returns how many commits the local branch is ahead of and behind the remote.
    ///
    /// Runs `git rev-list --left-right --count HEAD...@{upstream}` and parses
    /// the tab-separated output.
    ///
    /// - Returns: A tuple with `ahead` and `behind` commit counts.
    /// - Throws: `AppError` if the git command fails or output cannot be parsed.
    func aheadBehind() async throws -> (ahead: Int, behind: Int) {
        let sourceDir = try await sourceDirectory()
        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"]
        )
        return try GitService.parseAheadBehind(result.stdout)
    } // End of func aheadBehind()

    /// Returns the set of file paths that changed in commits the local branch is behind on.
    ///
    /// Runs `git diff --name-only HEAD...@{upstream}` to find files that differ
    /// between the current HEAD and the upstream tracking branch.
    ///
    /// - Returns: A set of relative file paths that changed remotely.
    /// - Throws: `AppError` if the git command fails.
    func remoteChangedFiles() async throws -> Set<String> {
        let sourceDir = try await sourceDirectory()
        let result = try await ProcessRunner.run(
            command: gitBinary,
            arguments: ["-C", sourceDir, "diff", "--name-only", "HEAD...@{upstream}"],
            throwOnFailure: false
        )

        // Exit code 0 means success; if there's no upstream or other issues,
        // we may get a non-zero code
        if result.exitCode != 0 {
            throw AppError.cliFailure(
                command: result.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return GitService.parseRemoteChangedFiles(result.stdout)
    } // End of func remoteChangedFiles()

    /// Parses the output of `git diff --name-only` into a set of file paths.
    ///
    /// Exposed as an internal static method to allow unit testing without
    /// running the actual git binary.
    ///
    /// - Parameter output: The raw stdout from `git diff --name-only`.
    /// - Returns: A set of non-empty file paths.
    static func parseRemoteChangedFiles(_ output: String) -> Set<String> {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(lines)
    } // End of static func parseRemoteChangedFiles(_:)

    /// Parses the `git rev-list --left-right --count` output into ahead/behind counts.
    ///
    /// Exposed as an internal static method to allow unit testing without
    /// running the actual git binary.
    ///
    /// - Parameter output: The raw stdout, expected format: `"N\tM"`.
    /// - Returns: A tuple with `ahead` and `behind` counts.
    /// - Throws: `AppError.parseFailure` if the output format is unexpected.
    static func parseAheadBehind(_ output: String) throws -> (ahead: Int, behind: Int) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: "\t")

        guard parts.count == 2,
              let ahead = Int(parts[0]),
              let behind = Int(parts[1]) else {
            throw AppError.parseFailure("Expected 'N\\tM' format from git rev-list, got: '\(trimmed)'")
        }

        return (ahead: ahead, behind: behind)
    } // End of static func parseAheadBehind(_:)
} // End of class GitService
