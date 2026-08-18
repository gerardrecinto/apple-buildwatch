import Foundation

/// One non-comment, non-blank line from a CODEOWNERS file.
public struct CodeOwnersEntry: Equatable, Sendable {
    public let pattern: String
    public let owners: [String]
    public let lineNumber: Int
    public let rawLine: String

    public init(pattern: String, owners: [String], lineNumber: Int, rawLine: String) {
        self.pattern = pattern
        self.owners = owners
        self.lineNumber = lineNumber
        self.rawLine = rawLine
    }
}

/// Parses CODEOWNERS file contents into an ordered list of pattern/owner
/// entries. Comments (`#`) and blank/whitespace-only lines are skipped.
/// A line with a pattern but no owners is kept (with an empty owners list)
/// rather than dropped, since that's valid CODEOWNERS syntax meaning
/// "explicitly unowned" -- callers decide what to do with it.
public enum CodeOwnersParser {
    public static func parse(contents: String) -> [CodeOwnersEntry] {
        var entries: [CodeOwnersEntry] = []

        for (offset, rawLine) in contents.components(separatedBy: .newlines).enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let pattern = tokens.first else { continue }

            entries.append(
                CodeOwnersEntry(
                    pattern: pattern,
                    owners: Array(tokens.dropFirst()),
                    lineNumber: offset + 1,
                    rawLine: rawLine
                )
            )
        }

        return entries
    }

    /// Returns the last entry whose pattern matches `path` (CODEOWNERS uses
    /// "last match wins", same as `.gitignore`), skipping entries with no
    /// owners since those explicitly disclaim ownership rather than assign it.
    public static func lastMatch(in entries: [CodeOwnersEntry], path: String) -> CodeOwnersEntry? {
        var winner: CodeOwnersEntry?
        for entry in entries where OwnershipGlob.matches(pattern: entry.pattern, path: path) {
            if !entry.owners.isEmpty {
                winner = entry
            }
        }
        return winner
    }
}
