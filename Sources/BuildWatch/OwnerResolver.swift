import Foundation

/// Resolves a likely owner for a build failure.
///
/// Priority order (first one that produces a match wins):
///   1. explicit config override (`.buildwatch-owners.json` at the repo root)
///   2. a CODEOWNERS file (`.github/CODEOWNERS`, `CODEOWNERS`, or `docs/CODEOWNERS`)
///   3. the legacy keyword/directory heuristic (kept as a last-resort fallback)
///   4. `.unknown` -- never guesses when there's no real evidence.
public struct OwnerResolver: Sendable {
    /// CODEOWNERS locations GitHub supports, checked in this order. We stop
    /// at the first one found and use only that file (files are not merged).
    private static let codeownersLocations = [".github/CODEOWNERS", "CODEOWNERS", "docs/CODEOWNERS"]

    private let maxFileBytes: Int

    /// - Parameter maxFileBytes: guard against reading an unexpectedly huge
    ///   CODEOWNERS/config file into memory. Files over this size are
    ///   treated as "not found" rather than read.
    public init(maxFileBytes: Int = 1_000_000) {
        self.maxFileBytes = maxFileBytes
    }

    public func resolve(
        evidence: [EvidenceLine],
        stackFrames: [StackFrame],
        git: GitContext,
        repoRoot: URL?
    ) -> OwnershipResult {
        let candidatePaths = failureFilePaths(stackFrames: stackFrames, git: git)

        if let repoRoot {
            if let configResult = resolveFromExplicitConfig(candidatePaths: candidatePaths, repoRoot: repoRoot) {
                return configResult
            }
            if let codeownersResult = resolveFromCodeowners(candidatePaths: candidatePaths, repoRoot: repoRoot) {
                return codeownersResult
            }
        }

        if let heuristic = legacyHeuristic(evidence: evidence, stackFrames: stackFrames, git: git) {
            return heuristic
        }

        return .unknown
    }

    // MARK: - Candidate paths

    private func failureFilePaths(stackFrames: [StackFrame], git: GitContext) -> [String] {
        stackFrames.compactMap(\.file) + git.changedFiles
    }

    // MARK: - Explicit config

    private func resolveFromExplicitConfig(candidatePaths: [String], repoRoot: URL) -> OwnershipResult? {
        let url = repoRoot.appendingPathComponent(OwnerConfigFile.fileName)
        guard let data = boundedContents(of: url), let config = OwnerConfigFile.parse(data: data) else {
            return nil
        }

        for path in candidatePaths {
            guard let override = config.lastMatch(path: path) else { continue }
            return OwnershipResult(
                owner: override.owner,
                confidence: .high,
                evidence: "\(path) matched \(OwnerConfigFile.fileName) override pattern \"\(override.pattern)\"",
                source: .explicitConfig
            )
        }

        return nil
    }

    // MARK: - CODEOWNERS

    private func resolveFromCodeowners(candidatePaths: [String], repoRoot: URL) -> OwnershipResult? {
        guard let (location, contents) = readCodeowners(repoRoot: repoRoot) else { return nil }
        let entries = CodeOwnersParser.parse(contents: contents)
        guard !entries.isEmpty else { return nil }

        for path in candidatePaths {
            guard let winner = CodeOwnersParser.lastMatch(in: entries, path: path) else { continue }
            let ownerText = winner.owners.joined(separator: ", ")
            return OwnershipResult(
                owner: ownerText,
                confidence: .high,
                evidence: "\(path) matched \(location) line \(winner.lineNumber): \"\(winner.rawLine.trimmingCharacters(in: .whitespaces))\"",
                source: .codeowners
            )
        }

        return nil
    }

    private func readCodeowners(repoRoot: URL) -> (location: String, contents: String)? {
        for relativePath in Self.codeownersLocations {
            let url = repoRoot.appendingPathComponent(relativePath)
            guard let data = boundedContents(of: url), let contents = String(data: data, encoding: .utf8) else {
                continue
            }
            return (relativePath, contents)
        }
        return nil
    }

    /// Reads file contents only if the file exists and is within
    /// `maxFileBytes`. Returns nil (never throws, never reads unbounded
    /// data) so a huge or unreadable file just falls through the priority
    /// chain instead of crashing or spiking memory.
    private func boundedContents(of url: URL) -> Data? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        if let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int, size > maxFileBytes {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    // MARK: - Legacy heuristic (last resort)

    private func legacyHeuristic(evidence: [EvidenceLine], stackFrames: [StackFrame], git: GitContext) -> OwnershipResult? {
        let candidates = stackFrames.compactMap(\.file) + evidence.map(\.text) + git.changedFiles

        for (keyword, owner) in [("network", "Networking"), ("media", "Media"), ("audio", "Media"), ("test", "Test Infrastructure")] {
            if let match = candidates.first(where: { $0.localizedCaseInsensitiveContains(keyword) }) {
                return OwnershipResult(
                    owner: owner,
                    confidence: .medium,
                    evidence: "keyword \"\(keyword)\" matched in: \(match)",
                    source: .gitHistoryHeuristic
                )
            }
        }

        if let firstChanged = git.changedFiles.first {
            let directory = (firstChanged as NSString).deletingLastPathComponent
            let owner = directory.isEmpty ? "Recent Change Owner" : (directory as NSString).lastPathComponent
            return OwnershipResult(
                owner: owner,
                confidence: .low,
                evidence: "no CODEOWNERS or keyword match; falling back to the directory of the first git-changed file: \(firstChanged)",
                source: .gitHistoryHeuristic
            )
        }

        return nil
    }
}
