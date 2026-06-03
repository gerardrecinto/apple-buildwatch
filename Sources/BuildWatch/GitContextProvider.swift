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
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
