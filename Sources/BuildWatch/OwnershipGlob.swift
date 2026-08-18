import Foundation

/// A minimal gitignore/CODEOWNERS-style glob matcher.
///
/// GitHub documents CODEOWNERS patterns as following the same rules as
/// `.gitignore`. This implements the subset that shows up in real
/// CODEOWNERS files:
///   - `*` matches any run of characters except `/`
///   - `**` matches any run of characters, including `/` (zero or more path segments)
///   - `?` matches a single character except `/`
///   - a pattern containing a `/` anywhere but the very end is anchored to the repo root
///   - a pattern with no `/` (or only a trailing `/`) matches the basename at any depth
///   - a trailing `/` restricts the pattern to a directory and everything under it
///
/// This is intentionally not a full gitignore engine (no negation, no
/// character classes) -- just enough to match real-world CODEOWNERS files
/// correctly and explainably.
public enum OwnershipGlob {
    public static func matches(pattern rawPattern: String, path rawPath: String) -> Bool {
        guard let regex = compile(rawPattern) else { return false }
        let path = normalize(rawPath)
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        return regex.firstMatch(in: path, options: [], range: range) != nil
    }

    private static func normalize(_ path: String) -> String {
        var value = path
        while value.hasPrefix("./") {
            value.removeFirst(2)
        }
        return value
    }

    private static func compile(_ rawPattern: String) -> NSRegularExpression? {
        var pattern = rawPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return nil }

        if pattern.hasSuffix("/") {
            pattern.removeLast()
        }
        guard !pattern.isEmpty else { return nil }

        // A slash in the middle or at the start anchors the pattern to the
        // repo root. A pattern with no slash (after stripping a trailing
        // one) is free to match at any depth, per gitignore semantics.
        let anchored = pattern.contains("/")

        if pattern.hasPrefix("/") {
            pattern.removeFirst()
        }
        guard !pattern.isEmpty else { return nil }

        let body = translate(pattern)
        let prefix = anchored ? "^" : "^(?:.*/)?"
        // A pattern can match either an exact file or a directory (and
        // everything below it), which is how GitHub treats directory-style
        // CODEOWNERS patterns.
        let suffix = "(?:/.*)?$"

        return try? NSRegularExpression(pattern: prefix + body + suffix)
    }

    private static func translate(_ pattern: String) -> String {
        var result = ""
        var index = pattern.startIndex

        while index < pattern.endIndex {
            let character = pattern[index]

            if character == "*" {
                let next = pattern.index(after: index)
                if next < pattern.endIndex, pattern[next] == "*" {
                    let afterNext = pattern.index(after: next)
                    if afterNext < pattern.endIndex, pattern[afterNext] == "/" {
                        // "**/" matches zero or more whole path segments.
                        result += "(?:.*/)?"
                        index = pattern.index(after: afterNext)
                        continue
                    } else {
                        // trailing "**" or "**" mid-segment: match anything.
                        result += ".*"
                        index = pattern.index(after: next)
                        continue
                    }
                }
                result += "[^/]*"
            } else if character == "?" {
                result += "[^/]"
            } else {
                result += NSRegularExpression.escapedPattern(for: String(character))
            }

            index = pattern.index(after: index)
        }

        return result
    }
}
