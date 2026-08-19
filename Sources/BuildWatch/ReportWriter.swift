import Foundation

public struct ReportWriter: Sendable {
    public init() {}

    public func terminal(_ analysis: BuildAnalysis) -> String {
        let evidence = analysis.evidence.map { "  line \($0.lineNumber): \($0.text)" }.joined(separator: "\n")
        let frames = analysis.stackFrames.map { frame in
            if let file = frame.file, let line = frame.line {
                return "  \(file):\(line) \(frame.symbol)"
            }
            return "  \(frame.symbol)"
        }.joined(separator: "\n")

        return """
        buildwatch
        status: \(analysis.status)
        failure: \(analysis.failureKind.rawValue)
        confidence: \(Int(analysis.confidence * 100))%
        branch: \(analysis.git.branch)
        sha: \(analysis.git.sha)
        likely_owner: \(analysis.likelyOwner.owner)
        owner_confidence: \(analysis.likelyOwner.confidence.rawValue)
        ownership_source: \(ownershipSourceLabel(analysis.likelyOwner.source))
        ownership_evidence: \(analysis.likelyOwner.evidence)

        summary:
          \(analysis.summary)

        suggested_action:
          \(analysis.suggestedAction)

        evidence:
        \(evidence.isEmpty ? "  none" : evidence)

        stack_context:
        \(frames.isEmpty ? "  none" : frames)
        """
    }

    public func markdown(_ analysis: BuildAnalysis) -> String {
        let evidence = analysis.evidence.map { "- line \($0.lineNumber): `\($0.text)`" }.joined(separator: "\n")
        let frames = analysis.stackFrames.map { frame in
            if let file = frame.file, let line = frame.line {
                return "- `\(file):\(line)` \(frame.symbol)"
            }
            return "- \(frame.symbol)"
        }.joined(separator: "\n")

        return """
        # BuildWatch Report

        | Field | Value |
        |---|---|
        | Status | \(analysis.status) |
        | Failure | \(analysis.failureKind.rawValue) |
        | Confidence | \(Int(analysis.confidence * 100))% |
        | Branch | \(analysis.git.branch) |
        | SHA | \(analysis.git.sha) |
        | Likely owner | \(analysis.likelyOwner.owner) |
        | Owner confidence | \(analysis.likelyOwner.confidence.rawValue) |
        | Ownership source | \(ownershipSourceLabel(analysis.likelyOwner.source)) |

        ## Ownership Evidence

        \(analysis.likelyOwner.evidence)

        ## Summary

        \(analysis.summary)

        ## Suggested Action

        \(analysis.suggestedAction)

        ## Evidence

        \(evidence.isEmpty ? "- none" : evidence)

        ## Stack Context

        \(frames.isEmpty ? "- none" : frames)
        """
    }

    private func ownershipSourceLabel(_ source: OwnershipSource) -> String {
        switch source {
        case .explicitConfig:
            return "\(OwnerConfigFile.fileName) (explicit override)"
        case .codeowners:
            return "CODEOWNERS"
        case .gitHistoryHeuristic:
            return "git-history heuristic"
        case .none:
            return "none (no signal found)"
        }
    }

    public func json(_ analysis: BuildAnalysis) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(analysis)
        return String(decoding: data, as: UTF8.self)
    }

    public func terminal(_ comparison: BuildComparison) -> String {
        """
        buildwatch compare
        transition: \(comparison.transition.rawValue)
        previous: \(comparison.previousStatus)\(comparison.previousFailureKind.map { " (\($0.rawValue))" } ?? "")
        current:  \(comparison.currentStatus)\(comparison.currentFailureKind.map { " (\($0.rawValue))" } ?? "")
        owner_changed: \(comparison.ownerChanged)\(ownerChangeLine(comparison))
        confidence_delta: \(signedPercent(comparison.confidenceDelta))
        branch_changed: \(comparison.branchChanged)
        sha_changed: \(comparison.shaChanged)

        summary:
          \(comparison.summary)
        """
    }

    public func markdown(_ comparison: BuildComparison) -> String {
        """
        # BuildWatch Compare

        | Field | Previous | Current |
        |---|---|---|
        | Status | \(comparison.previousStatus) | \(comparison.currentStatus) |
        | Failure | \(comparison.previousFailureKind?.rawValue ?? "-") | \(comparison.currentFailureKind?.rawValue ?? "-") |
        | Owner | \(comparison.previousOwner ?? "-") | \(comparison.currentOwner ?? "-") |

        **Transition:** \(comparison.transition.rawValue)
        **Confidence delta:** \(signedPercent(comparison.confidenceDelta))
        **Branch changed:** \(comparison.branchChanged) · **SHA changed:** \(comparison.shaChanged)

        ## Summary

        \(comparison.summary)
        """
    }

    public func json(_ comparison: BuildComparison) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(comparison)
        return String(decoding: data, as: UTF8.self)
    }

    private func ownerChangeLine(_ comparison: BuildComparison) -> String {
        guard comparison.ownerChanged, let previous = comparison.previousOwner, let current = comparison.currentOwner else {
            return ""
        }
        return " (\(previous) -> \(current))"
    }

    private func signedPercent(_ delta: Double) -> String {
        String(format: "%+.0f%%", delta * 100)
    }
}
