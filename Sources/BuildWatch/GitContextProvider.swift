import Foundation

public struct GitContextProvider: Sendable {
    public init() {}

    public func readGitContext(workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> GitContext {
        let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], workingDirectory: workingDirectory) ?? "unknown"
        let sha = runGit(["rev-parse", "--short", "HEAD"], workingDirectory: workingDirectory) ?? "unknown"
        let changed = runGit(["diff", "--name-only", "HEAD"], workingDirectory: workingDirectory)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []

        return GitContext(branch: branch, sha: sha, changedFiles: changed)
    }

    /// The top-level directory of the git repository containing
    /// `workingDirectory`, or nil if it isn't inside a git repo (or `git`
    /// isn't available). Used to locate CODEOWNERS and owner-override
    /// config files relative to the repo root rather than the current
    /// working directory.
    public func repositoryRoot(workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL? {
        guard let path = runGit(["rev-parse", "--show-toplevel"], workingDirectory: workingDirectory) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func runGit(_ args: [String], workingDirectory: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = workingDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            // Drain the pipe before waiting, same fix as BuildRunner: `git
            // diff --name-only` on a large changeset can exceed the pipe's
            // ~64KB buffer, and waiting first would deadlock the child on
            // its blocked write.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
