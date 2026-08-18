import Foundation

/// One entry in the optional `.buildwatch-owners.json` override file.
public struct OwnerOverride: Codable, Equatable, Sendable {
    public let pattern: String
    public let owner: String

    public init(pattern: String, owner: String) {
        self.pattern = pattern
        self.owner = owner
    }
}

/// The optional `.buildwatch-owners.json` file, checked at the repo root.
/// This lets a team hardcode a friendly owner name for a path without
/// needing (or being able) to edit CODEOWNERS -- e.g. renaming a raw
/// `@github-handle` to a readable team name, or covering a path CODEOWNERS
/// doesn't. It uses the same last-match-wins glob semantics as CODEOWNERS
/// and takes priority over it.
///
/// Format:
/// ```json
/// {
///   "overrides": [
///     { "pattern": "Sources/Media/**", "owner": "Media Platform Team" }
///   ]
/// }
/// ```
public struct OwnerConfigFile: Codable, Equatable, Sendable {
    public let overrides: [OwnerOverride]

    public init(overrides: [OwnerOverride]) {
        self.overrides = overrides
    }

    public static let fileName = ".buildwatch-owners.json"

    public static func parse(data: Data) -> OwnerConfigFile? {
        try? JSONDecoder().decode(OwnerConfigFile.self, from: data)
    }

    /// Returns the last override whose pattern matches `path`.
    public func lastMatch(path: String) -> OwnerOverride? {
        var winner: OwnerOverride?
        for override in overrides where OwnershipGlob.matches(pattern: override.pattern, path: path) {
            winner = override
        }
        return winner
    }
}
