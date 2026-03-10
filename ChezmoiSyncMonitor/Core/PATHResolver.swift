import Foundation

/// Resolves the full path of CLI executables for use inside a sandboxed .app bundle.
///
/// GUI apps do not inherit the user's shell PATH, so this utility probes
/// well-known directories and optionally queries the user's login shell.
enum PATHResolver: Sendable {

    /// Well-known directories to probe, in priority order.
    private static let probePaths: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        NSHomeDirectory() + "/.local/bin",
        "/usr/bin",
        "/usr/sbin"
    ]

    /// Cache of previously resolved executable paths, keyed by executable name.
    private nonisolated(unsafe) static let cache = NSCache<NSString, NSString>()

    /// Finds the full path of a named executable.
    ///
    /// Checks a cache first, then probes well-known directories, and finally
    /// attempts to extract the user's shell PATH for additional search locations.
    ///
    /// - Parameter name: The executable name (e.g., `"chezmoi"`, `"git"`).
    /// - Returns: The full path if found, or `nil`.
    static func findExecutable(_ name: String) -> String? {
        // Check cache first
        if let cached = cache.object(forKey: name as NSString) {
            return cached as String
        }

        // Probe well-known directories
        for dir in probePaths {
            let fullPath = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                cache.setObject(fullPath as NSString, forKey: name as NSString)
                return fullPath
            }
        } // End of loop through probePaths

        // Try extracting PATH from user's login shell
        if let shellPaths = extractShellPATH() {
            for dir in shellPaths {
                let fullPath = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    cache.setObject(fullPath as NSString, forKey: name as NSString)
                    return fullPath
                }
            } // End of loop through shellPaths
        }

        return nil
    } // End of static func findExecutable(_:)

    /// Convenience method to find the chezmoi executable.
    ///
    /// - Returns: The full path to chezmoi, or `nil` if not found.
    static func chezmoiPath() -> String? {
        return findExecutable("chezmoi")
    }

    /// Convenience method to find the git executable.
    ///
    /// - Returns: The full path to git, or `nil` if not found.
    static func gitPath() -> String? {
        return findExecutable("git")
    }

    /// Extracts the PATH variable from the user's login shell.
    ///
    /// Tries zsh first (default on macOS), then bash. Returns the PATH
    /// entries split by `:`, or `nil` if extraction fails.
    ///
    /// - Returns: An array of directory paths, or `nil`.
    private static func extractShellPATH() -> [String]? {
        let shells = ["/bin/zsh", "/bin/bash"]

        for shell in shells {
            guard FileManager.default.isExecutableFile(atPath: shell) else { continue }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-l", "-c", "echo $PATH"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe() // Discard stderr

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let pathString = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !pathString.isEmpty {
                        return pathString.components(separatedBy: ":")
                    }
                }
            } catch {
                continue
            }
        } // End of loop through shells

        return nil
    } // End of static func extractShellPATH()
} // End of enum PATHResolver
