import Foundation

/// How a build's outcome moved between two `BuildAnalysis` snapshots.
public enum BuildTransition: String, Codable, Equatable, Sendable {
    /// Was passing (or wasn't sampled), now failing.
    case regressed
    /// Was failing, now passing.
    case resolved
    /// Failing in both, same `FailureKind` — the same underlying problem, still open.
    case persisting
    /// Failing in both, but the classified `FailureKind` differs — still red,
    /// different root cause than last time.
    case changed
    /// Passing in both.
    case stable
}

public struct BuildComparison: Codable, Equatable, Sendable {
    public let transition: BuildTransition
    public let previousStatus: String
    public let currentStatus: String
    public let previousFailureKind: FailureKind?
    public let currentFailureKind: FailureKind?
    public let ownerChanged: Bool
    public let previousOwner: String?
    public let currentOwner: String?
    public let confidenceDelta: Double
    public let branchChanged: Bool
    public let shaChanged: Bool
    public let summary: String

    public init(
        transition: BuildTransition,
        previousStatus: String,
        currentStatus: String,
        previousFailureKind: FailureKind?,
        currentFailureKind: FailureKind?,
        ownerChanged: Bool,
        previousOwner: String?,
        currentOwner: String?,
        confidenceDelta: Double,
        branchChanged: Bool,
        shaChanged: Bool,
        summary: String
    ) {
        self.transition = transition
        self.previousStatus = previousStatus
        self.currentStatus = currentStatus
        self.previousFailureKind = previousFailureKind
        self.currentFailureKind = currentFailureKind
        self.ownerChanged = ownerChanged
        self.previousOwner = previousOwner
        self.currentOwner = currentOwner
        self.confidenceDelta = confidenceDelta
        self.branchChanged = branchChanged
        self.shaChanged = shaChanged
        self.summary = summary
    }
}

/// Diffs two `BuildAnalysis` snapshots — typically last night's `analyze
/// --format json` output against today's — into a single build-over-build
/// transition. `BuildAnalysis` models one failure per run (this tool
/// classifies a single build/test invocation, not a full multi-test
/// report), so "compare" here means "is this the same problem as last
/// time, a new one, or is it gone" rather than a per-test failure diff.
public struct BuildComparator: Sendable {
    public init() {}

    public func compare(previous: BuildAnalysis, current: BuildAnalysis) -> BuildComparison {
        let previousFailed = Self.isFailing(previous.status)
        let currentFailed = Self.isFailing(current.status)

        let transition: BuildTransition
        switch (previousFailed, currentFailed) {
        case (false, false):
            transition = .stable
        case (false, true):
            transition = .regressed
        case (true, false):
            transition = .resolved
        case (true, true):
            transition = previous.failureKind == current.failureKind ? .persisting : .changed
        }

        let ownerChanged = previousFailed && currentFailed && previous.likelyOwner.owner != current.likelyOwner.owner

        return BuildComparison(
            transition: transition,
            previousStatus: previous.status,
            currentStatus: current.status,
            previousFailureKind: previousFailed ? previous.failureKind : nil,
            currentFailureKind: currentFailed ? current.failureKind : nil,
            ownerChanged: ownerChanged,
            previousOwner: previousFailed ? previous.likelyOwner.owner : nil,
            currentOwner: currentFailed ? current.likelyOwner.owner : nil,
            confidenceDelta: current.confidence - previous.confidence,
            branchChanged: previous.git.branch != current.git.branch,
            shaChanged: previous.git.sha != current.git.sha,
            summary: Self.summarize(
                transition: transition, previous: previous, current: current, ownerChanged: ownerChanged
            )
        )
    }

    private static func isFailing(_ status: String) -> Bool {
        status.lowercased() == "failed"
    }

    private static func summarize(
        transition: BuildTransition, previous: BuildAnalysis, current: BuildAnalysis, ownerChanged: Bool
    ) -> String {
        switch transition {
        case .stable:
            return "Build is passing, same as the previous run."
        case .regressed:
            return "Build newly failing: \(current.failureKind.rawValue) (previous run passed)."
        case .resolved:
            return "Build recovered: \(previous.failureKind.rawValue) is no longer failing."
        case .persisting:
            let ownerNote = ownerChanged
                ? " Likely owner moved from \(previous.likelyOwner.owner) to \(current.likelyOwner.owner)."
                : ""
            return "Same failure persisting: \(current.failureKind.rawValue).\(ownerNote)"
        case .changed:
            return "Still failing, but the root cause changed: "
                + "\(previous.failureKind.rawValue) -> \(current.failureKind.rawValue)."
        }
    }
}
