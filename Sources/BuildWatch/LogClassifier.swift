import Foundation

public struct LogClassifier: Sendable {
    private struct Rule: Sendable {
        let kind: FailureKind
        let pattern: String
        let summary: String
        let action: String
        let confidence: Double
    }

    private let rules: [Rule] = [
        Rule(
            kind: .codeSigningFailure,
            pattern: #"(?i)(code ?sign|provisioning profile|No signing certificate|Signing for .* requires)"#,
            summary: "Code signing or provisioning failed.",
            action: "Check signing identity, provisioning profile, team ID, and build configuration.",
            confidence: 0.94
        ),
        Rule(
            kind: .simulatorFailure,
            pattern: #"(?i)(simctl|CoreSimulator|Simulator.*timed out|failed to boot simulator)"#,
            summary: "Simulator infrastructure failed before tests could complete.",
            action: "Reset the simulator runtime, verify destination availability, and retry once before routing to product code.",
            confidence: 0.90
        ),
        Rule(
            kind: .testFailure,
            pattern: #"(?i)(Test Case .+ failed|XCTAssert|\\*\\* TEST FAILED \\*\\*)"#,
            summary: "XCTest reported a product or test assertion failure.",
            action: "Open the failing test, compare recent git changes, and confirm whether the failure reproduces locally.",
            confidence: 0.91
        ),
        Rule(
            kind: .flakyTestCandidate,
            pattern: #"(?i)(timed out waiting|async operation did not complete|intermittent|flaky)"#,
            summary: "The failure has timing or recurrence signals that look flaky.",
            action: "Retry once, compare historical failures, and quarantine only with recurrence evidence.",
            confidence: 0.83
        ),
        Rule(
            kind: .linkerError,
            pattern: #"(?i)(Undefined symbols for architecture|duplicate symbol|ld: symbol|linker command failed)"#,
            summary: "The build failed during linking.",
            action: "Inspect linked frameworks, duplicate object files, target membership, and library search paths.",
            confidence: 0.93
        ),
        Rule(
            kind: .compilerError,
            pattern: #"(?i)(error:|use of unresolved identifier|cannot find|cannot convert value|no member named|SwiftCompile failed)"#,
            summary: "The compiler found a source or module issue.",
            action: "Inspect the first compiler error, imports, module visibility, generated files, and recent source changes.",
            confidence: 0.89
        ),
        Rule(
            kind: .missingDependency,
            pattern: #"(?i)(No such module|package resolution failed|could not resolve package|module not found|No rule to make target)"#,
            summary: "A dependency or build target is missing.",
            action: "Check package resolution, workspace setup, Makefile target names, and artifact availability.",
            confidence: 0.88
        ),
        Rule(
            kind: .networkFailure,
            pattern: #"(?i)(TLS handshake|connection reset|network is unreachable|timed out while downloading|403|404)"#,
            summary: "The build failed while fetching a remote dependency or artifact.",
            action: "Verify artifact host health, credentials, retry policy, and local cache state.",
            confidence: 0.82
        ),
        Rule(
            kind: .timeout,
            pattern: #"(?i)(Build timed out|Command timed out|exceeded .* timeout|SIGKILL|Killed: 9)"#,
            summary: "The build exceeded a timeout or was killed.",
            action: "Check the slowest stage, resource pressure, runaway tests, and worker capacity.",
            confidence: 0.84
        ),
        Rule(
            kind: .infrastructureFailure,
            pattern: #"(?i)(No space left on device|disk full|xcode-select|DerivedData|resource temporarily unavailable)"#,
            summary: "The build worker or local toolchain environment failed.",
            action: "Check disk, selected Xcode, DerivedData state, worker health, and retry on a clean worker.",
            confidence: 0.86
        )
    ]

    public init() {}

    public func analyze(log: String, git: GitContext = .unavailable) -> BuildAnalysis {
        let lines = log.components(separatedBy: .newlines)
        let stackFrames = StackTraceExtractor().extract(from: log)

        for rule in rules {
            let regex = try? NSRegularExpression(pattern: rule.pattern)
            let evidence = matchingEvidence(lines: lines, regex: regex)
            if !evidence.isEmpty {
                return BuildAnalysis(
                    status: "failed",
                    failureKind: rule.kind,
                    confidence: rule.confidence,
                    summary: rule.summary,
                    suggestedAction: rule.action,
                    evidence: Array(evidence.prefix(5)),
                    stackFrames: Array(stackFrames.prefix(5)),
                    likelyOwner: OwnerResolver().resolve(from: evidence, stackFrames: stackFrames, git: git),
                    git: git
                )
            }
        }

        return BuildAnalysis(
            status: log.localizedCaseInsensitiveContains("BUILD SUCCEEDED") ? "passed" : "failed",
            failureKind: .unknown,
            confidence: 0.30,
            summary: "No high-confidence failure rule matched this log.",
            suggestedAction: "Inspect the first non-warning error line and compare against recent source, dependency, and worker changes.",
            evidence: Array(lines.enumerated().filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }.prefix(5).map {
                EvidenceLine(lineNumber: $0.offset + 1, text: $0.element)
            }),
            stackFrames: Array(stackFrames.prefix(5)),
            likelyOwner: OwnerResolver().resolve(from: [], stackFrames: stackFrames, git: git),
            git: git
        )
    }

    private func matchingEvidence(lines: [String], regex: NSRegularExpression?) -> [EvidenceLine] {
        guard let regex else { return [] }
        return lines.enumerated().compactMap { index, line in
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard regex.firstMatch(in: line, range: range) != nil else { return nil }
            return EvidenceLine(lineNumber: index + 1, text: line)
        }
    }
}

private struct OwnerResolver: Sendable {
    func resolve(from evidence: [EvidenceLine], stackFrames: [StackFrame], git: GitContext) -> String? {
        let candidates = stackFrames.compactMap(\.file) + evidence.map(\.text) + git.changedFiles
        if let match = candidates.first(where: { $0.localizedCaseInsensitiveContains("network") }) {
            return ownerName(from: match, fallback: "Networking")
        }
        if let match = candidates.first(where: { $0.localizedCaseInsensitiveContains("media") || $0.localizedCaseInsensitiveContains("audio") }) {
            return ownerName(from: match, fallback: "Media")
        }
        if let match = candidates.first(where: { $0.localizedCaseInsensitiveContains("test") }) {
            return ownerName(from: match, fallback: "Test Infrastructure")
        }
        return git.changedFiles.first.map { ownerName(from: $0, fallback: "Recent Change Owner") }
    }

    private func ownerName(from value: String, fallback: String) -> String {
        let lowered = value.lowercased()
        if lowered.contains("network") { return "Networking" }
        if lowered.contains("media") || lowered.contains("audio") { return "Media" }
        if lowered.contains("test") { return "Test Infrastructure" }
        return fallback
    }
}
